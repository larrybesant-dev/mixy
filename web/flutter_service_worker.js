// Legacy safety worker.
// If this file is ever registered by older clients, it should clean up and
// unregister itself instead of intercepting network requests.
self.addEventListener('install', () => {
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    const cacheKeys = await caches.keys();
    await Promise.all(cacheKeys.map((key) => caches.delete(key)));

    try {
      await self.registration.unregister();
    } catch (e) {
      // Unregister not supported by this browser; use claim as fallback.
      await self.clients.claim();
    }

    const windows = await self.clients.matchAll({ type: 'window' });
    await Promise.all(windows.map(async (client) => {
      try {
        await client.navigate(client.url);
      } catch (_e) {
        // Client may be cross-origin or no longer navigable; skip.
      }
    }));
  })());
});
