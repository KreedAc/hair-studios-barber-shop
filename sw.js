const CACHE = 'hairstudios-v5';
const PRECACHE = ['/'];
const NETWORK_TIMEOUT = 3000; // ms: oltre questo, su rete lenta si usa la cache

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
