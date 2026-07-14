const CACHE = 'hairstudios-v7';
const PRECACHE = ['/'];
const NETWORK_TIMEOUT = 3000; // ms: oltre questo, su rete lenta si usa la cache

// ── NOTIFICHE PUSH ──────────────────────────────────────────────
self.addEventListener('push', e => {
  let data = {};
  try { data = e.data ? e.data.json() : {}; } catch (_) { data = { body: e.data && e.data.text() }; }
  const title = data.title || 'Hair Studios';
  e.waitUntil(self.registration.showNotification(title, {
    body: data.body || '',
    icon: '/icon-192.png',
    badge: '/icon-192.png',
    tag: data.tag,
    renotify: !!data.tag,
    data: { url: data.url || '/' },
  }));
});

self.addEventListener('notificationclick', e => {
  e.notification.close();
  const url = (e.notification.data && e.notification.data.url) || '/';
  e.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then(list => {
      for (const c of list) { if ('focus' in c) { c.navigate(url); return c.focus(); } }
      if (self.clients.openWindow) return self.clients.openWindow(url);
    })
  );
});

self.addEventListener('install', e => {
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(PRECACHE)));
  self.skipWaiting();
});

self.addEventListener('activate', e => {
  e.waitUntil(
    caches.keys().then(keys =>
      Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k)))
    )
  );
  self.clients.claim();
});

self.addEventListener('fetch', e => {
  if (e.request.method !== 'GET') return;
  if (e.request.url.includes('supabase.co')) return; // mai cachare le API

  // CDN (React, Babel, Supabase JS, font Google) → cache first: non cambiano mai
  const isCDN = ['cdn.jsdelivr.net','unpkg.com','fonts.googleapis.com','fonts.gstatic.com','esm.sh']
    .some(h => e.request.url.includes(h));

  if (isCDN) {
    e.respondWith(
      caches.match(e.request).then(cached => cached ||
        fetch(e.request).then(res => {
          if (res.ok) caches.open(CACHE).then(c => c.put(e.request, res.clone()));
          return res;
        })
      )
    );
    return;
  }

  // File app → network first con timeout: aggiornamenti immediati,
  // ma su rete lenta/assente si cade sulla cache entro 3 secondi
  e.respondWith((async () => {
    const cached  = await caches.match(e.request);
    const network = fetch(e.request).then(res => {
      if (res.ok) {
        const clone = res.clone();
        caches.open(CACHE).then(c => c.put(e.request, clone));
      }
      return res;
    }).catch(() => null);

    if (!cached) {
      const res = await network;
      return res || new Response('Offline', { status: 503 });
    }

    const winner = await Promise.race([
      network,
      new Promise(resolve => setTimeout(() => resolve('TIMEOUT'), NETWORK_TIMEOUT)),
    ]);
    return (winner && winner !== 'TIMEOUT') ? winner : cached;
  })());
});
