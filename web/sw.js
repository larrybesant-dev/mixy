// Service Worker for MixVy
// No-op service worker that simply registers without intercepting requests.
// Firestore, Auth, and other APIs are handled by the browser natively.
// AppCheck is disabled on web; Firestore Security Rules provide security layer.

console.log('[Service Worker] MixVy service worker registered');
