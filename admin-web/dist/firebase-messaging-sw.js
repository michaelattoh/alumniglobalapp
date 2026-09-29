/* eslint-disable no-undef */
importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-messaging-compat.js');

const params = new URLSearchParams(self.location.search);

const firebaseConfig = {
  apiKey: params.get('apiKey') || '',
  authDomain: params.get('authDomain') || '',
  projectId: params.get('projectId') || '',
  storageBucket: params.get('storageBucket') || '',
  messagingSenderId: params.get('messagingSenderId') || '',
  appId: params.get('appId') || '',
};

const hasRequiredConfig = firebaseConfig.apiKey && firebaseConfig.projectId && firebaseConfig.messagingSenderId && firebaseConfig.appId;

function routeForPayload(data) {
  if (data?.route) return data.route;
  const screen = data?.screen || '';
  if (screen === 'institutions') return '/super/institutions';
  if (screen === 'users') return '/super/users';
  if (screen === 'support') return '/super/support';
  return '/';
}

if (hasRequiredConfig) {
  firebase.initializeApp(firebaseConfig);
  const messaging = firebase.messaging();

  messaging.onBackgroundMessage((payload) => {
    const title = payload?.notification?.title || 'Alumni Global Network';
    const options = {
      body: payload?.notification?.body || 'You have a new notification.',
      data: payload?.data || {},
      tag: `agn-admin-${payload?.data?.notification_id || Date.now()}`,
    };

    self.registration.showNotification(title, options);
  });
}

self.addEventListener('notificationclick', (event) => {
  event.notification.close();

  const targetPath = routeForPayload(event.notification?.data || {});
  const targetUrl = new URL(targetPath, self.location.origin).toString();

  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((windowClients) => {
      for (const client of windowClients) {
        if (client.url.startsWith(self.location.origin) && 'focus' in client) {
          client.navigate(targetUrl);
          return client.focus();
        }
      }

      if (clients.openWindow) {
        return clients.openWindow(targetUrl);
      }

      return null;
    }),
  );
});
