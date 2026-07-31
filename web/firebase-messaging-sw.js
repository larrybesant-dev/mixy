/* eslint-disable no-undef */

importScripts('https://www.gstatic.com/firebasejs/10.12.4/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.4/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyCM6_Eye8JMEW7dXFpo-i-Frp4t3owyh_I',
  authDomain: 'mixvy-v2.firebaseapp.com',
  projectId: 'mixvy-v2',
  storageBucket: 'mixvy-v2.firebasestorage.app',
  messagingSenderId: '770164332233',
  appId: '1:770164332233:web:ae8bae1c4c68b525c3df18',
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
