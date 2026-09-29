const FIREBASE_APP_URL = 'https://www.gstatic.com/firebasejs/10.14.1/firebase-app-compat.js';
const FIREBASE_MESSAGING_URL = 'https://www.gstatic.com/firebasejs/10.14.1/firebase-messaging-compat.js';
const PUSH_TOKEN_STORAGE_KEY = 'admin_web_push_token';
const PUSH_DEVICE_ID_STORAGE_KEY = 'admin_web_push_device_id';

let firebaseScriptsPromise = null;
let foregroundUnsubscribe = null;

function loadScript(src) {
  return new Promise((resolve, reject) => {
    const existing = document.querySelector(`script[data-src="${src}"]`);
    if (existing) {
      if (existing.dataset.loaded === 'true') {
        resolve();
        return;
      }
      existing.addEventListener('load', () => resolve(), { once: true });
      existing.addEventListener('error', () => reject(new Error(`Unable to load ${src}`)), { once: true });
      return;
    }

    const script = document.createElement('script');
    script.src = src;
    script.async = true;
    script.dataset.src = src;
    script.onload = () => {
      script.dataset.loaded = 'true';
      resolve();
    };
    script.onerror = () => reject(new Error(`Unable to load ${src}`));
    document.head.appendChild(script);
  });
}

async function loadFirebaseCompat() {
  if (typeof window === 'undefined') {
    throw new Error('Firebase web push requires a browser environment.');
  }

  if (!firebaseScriptsPromise) {
    firebaseScriptsPromise = (async () => {
      await loadScript(FIREBASE_APP_URL);
      await loadScript(FIREBASE_MESSAGING_URL);
      if (!window.firebase?.messaging) {
        throw new Error('Firebase Messaging SDK did not load.');
      }
      return window.firebase;
    })();
  }

  return firebaseScriptsPromise;
}

export function getFirebaseWebConfig() {
  const config = {
    apiKey: import.meta.env.VITE_FIREBASE_API_KEY,
    authDomain: import.meta.env.VITE_FIREBASE_AUTH_DOMAIN,
    projectId: import.meta.env.VITE_FIREBASE_PROJECT_ID,
    storageBucket: import.meta.env.VITE_FIREBASE_STORAGE_BUCKET,
    messagingSenderId: import.meta.env.VITE_FIREBASE_MESSAGING_SENDER_ID,
    appId: import.meta.env.VITE_FIREBASE_APP_ID,
    vapidKey: import.meta.env.VITE_FIREBASE_VAPID_KEY,
  };

  const required = ['apiKey', 'authDomain', 'projectId', 'messagingSenderId', 'appId', 'vapidKey'];
  const missing = required.filter((key) => !config[key]);

  if (missing.length > 0) {
    return { config: null, missing };
  }

  return { config, missing: [] };
}

export function isFirebaseWebPushSupported() {
  return (
    typeof window !== 'undefined' &&
    'Notification' in window &&
    'serviceWorker' in navigator
  );
}

function getOrCreateDeviceId() {
  if (typeof window === 'undefined') return 'admin-web';
  const existing = window.localStorage.getItem(PUSH_DEVICE_ID_STORAGE_KEY);
  if (existing) return existing;
  const created = `admin-web-${Math.random().toString(36).slice(2, 12)}`;
  window.localStorage.setItem(PUSH_DEVICE_ID_STORAGE_KEY, created);
  return created;
}

function getStoredToken() {
  if (typeof window === 'undefined') return '';
  return window.localStorage.getItem(PUSH_TOKEN_STORAGE_KEY) || '';
}

function setStoredToken(token) {
  if (typeof window === 'undefined') return;
  if (!token) {
    window.localStorage.removeItem(PUSH_TOKEN_STORAGE_KEY);
    return;
  }
  window.localStorage.setItem(PUSH_TOKEN_STORAGE_KEY, token);
}

function buildServiceWorkerUrl(config) {
  const url = new URL('/firebase-messaging-sw.js', window.location.origin);
  url.searchParams.set('apiKey', config.apiKey);
  url.searchParams.set('authDomain', config.authDomain);
  url.searchParams.set('projectId', config.projectId);
  url.searchParams.set('storageBucket', config.storageBucket || '');
  url.searchParams.set('messagingSenderId', config.messagingSenderId);
  url.searchParams.set('appId', config.appId);
  return url.toString();
}

async function getMessagingContext(onMessage) {
  const { config, missing } = getFirebaseWebConfig();
  if (!config) {
    throw new Error(`Firebase web push config is incomplete: ${missing.join(', ')}`);
  }

  const firebase = await loadFirebaseCompat();
  const app = firebase.apps?.length ? firebase.app() : firebase.initializeApp(config);
  const messaging = firebase.messaging(app);
  const registration = await navigator.serviceWorker.register(buildServiceWorkerUrl(config));

  if (foregroundUnsubscribe) {
    foregroundUnsubscribe();
    foregroundUnsubscribe = null;
  }
  if (typeof onMessage === 'function') {
    foregroundUnsubscribe = messaging.onMessage(onMessage);
  }

  return { messaging, registration, config };
}

export async function enableFirebaseWebPush({ onMessage }) {
  if (!isFirebaseWebPushSupported()) {
    throw new Error('This browser does not support web push.');
  }

  const permission = await window.Notification.requestPermission();
  if (permission !== 'granted') {
    throw new Error('Browser notification permission was not granted.');
  }

  const { messaging, registration, config } = await getMessagingContext(onMessage);
  const token = await messaging.getToken({
    vapidKey: config.vapidKey,
    serviceWorkerRegistration: registration,
  });

  if (!token) {
    throw new Error('Firebase did not return a web push token.');
  }

  setStoredToken(token);

  return {
    token,
    deviceId: getOrCreateDeviceId(),
  };
}

export async function initializeFirebaseWebPush({ onMessage }) {
  if (!isFirebaseWebPushSupported()) {
    return { enabled: false, reason: 'unsupported' };
  }

  const { config } = getFirebaseWebConfig();
  if (!config) {
    return { enabled: false, reason: 'missing-config' };
  }

  if (window.Notification.permission !== 'granted') {
    return { enabled: false, reason: window.Notification.permission || 'default' };
  }

  const { messaging, registration } = await getMessagingContext(onMessage);
  const token = await messaging.getToken({
    vapidKey: config.vapidKey,
    serviceWorkerRegistration: registration,
  });

  if (!token) {
    return { enabled: false, reason: 'no-token' };
  }

  setStoredToken(token);

  return {
    enabled: true,
    token,
    deviceId: getOrCreateDeviceId(),
  };
}

export async function disableFirebaseWebPush() {
  if (typeof window === 'undefined') return { token: '' };
  const token = getStoredToken();
  setStoredToken('');
  if (foregroundUnsubscribe) {
    foregroundUnsubscribe();
    foregroundUnsubscribe = null;
  }
  return { token, deviceId: getOrCreateDeviceId() };
}
