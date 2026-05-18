const CACHE = 'hairstudios-v4';
const PRECACHE = ['/'];

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

  // File app (index.html, logo, manifest, sw…) → network first, cache fallback
  // Così gli aggiornamenti arrivano subito a chi ha la webapp installata
  e.respondWith(
    fetch(e.request)
      .then(res => {
        if (res.ok) caches.open(CACHE).then(c => c.put(e.request, res.clone()));
        return res;
      })
      .catch(() => caches.match(e.request))
  );
});
