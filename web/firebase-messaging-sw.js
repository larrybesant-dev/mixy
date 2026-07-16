/* eslint-disable no-undef */

// Disable AppCheck on web platform
self.__FIREBASE_DISABLE_APP_CHECK_ON_WEB = true;

importScripts('https://www.gstatic.com/firebasejs/10.12.4/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.4/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyBBmz9ybuDRCA2dAVjFZVj7R7wrDL0wTYU',
  authDomain: 'mix-and-mingle-v2.firebaseapp.com',
  projectId: 'mix-and-mingle-v2',
  storageBucket: 'mix-and-mingle-v2.firebasestorage.app',
  messagingSenderId: '980846719834',
  appId: '1:980846719834:web:4f26d018877528c3077963',
  measurementId: 'G-DRXWK1PPEK',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage(function (payload) {
  const notification = payload && payload.notification ? payload.notification : {};
  const title = notification.title || 'MixVy';
  const options = {
    body: notification.body || '',
    icon: './icons/Icon-192.png',
    data: payload && payload.data ? payload.data : {},
  };

  self.registration.showNotification(title, options);
});

firebase.initializeApp({
  apiKey: 'AIzaSyBBmz9ybuDRCA2dAVjFZVj7R7wrDL0wTYU',
  authDomain: 'mix-and-mingle-v2.firebaseapp.com',
  projectId: 'mix-and-mingle-v2',
  storageBucket: 'mix-and-mingle-v2.firebasestorage.app',
  messagingSenderId: '980846719834',
  appId: '1:980846719834:web:4f26d018877528c3077963',
  measurementId: 'G-DRXWK1PPEK',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage(function (payload) {
  const notification = payload && payload.notification ? payload.notification : {};
  const title = notification.title || 'MixVy';
  const options = {
    body: notification.body || '',
    icon: './icons/Icon-192.png',
    data: payload && payload.data ? payload.data : {},
  };

  self.registration.showNotification(title, options);
});
