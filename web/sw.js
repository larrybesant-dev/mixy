// Service Worker for MixVy
// Handles cache-first strategy for assets and passes through API requests

self.addEventListener('fetch', function(event) {
  // Let all requests pass through normally
  // AppCheck is disabled on web; Firestore Security Rules provide security layer
});

console.log('[Service Worker] MixVy service worker registered');
