// Firebase Cloud Messaging Service Worker
// Necessário para receber notificações push no Flutter Web.
// Este arquivo DEVE estar na raiz do diretório `web/`.
//
// NOTA: A Push API via Service Worker só é suportada no Safari a partir do
// iOS 16.4. Em versões anteriores, qualquer erro aqui quebrava silenciosamente
// o app inteiro. O try/catch abaixo isola a falha.

try {
  importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-app-compat.js');
  importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-messaging-compat.js');

  firebase.initializeApp({
    apiKey: "AIzaSyAwt_86QnX4ZM1e1lvA5Jpjcb6sasddpmQ",
    authDomain: "spark-v1-e0eb5.firebaseapp.com",
    projectId: "spark-v1-e0eb5",
    storageBucket: "spark-v1-e0eb5.firebasestorage.app",
    messagingSenderId: "35902836822",
    appId: "1:35902836822:web:0de2aca9dcc106864c6bf7",
    measurementId: "G-ST5QPRJNH3",
  });

  const messaging = firebase.messaging();

  // Handler para notificações recebidas com app em background
  messaging.onBackgroundMessage((payload) => {
    console.log('[firebase-messaging-sw.js] Background message received:', payload);

    const notificationTitle = payload.notification?.title ?? 'Spark';
    const notificationOptions = {
      body: payload.notification?.body ?? '',
      icon: '/icons/Icon-192.png',
    };

    self.registration.showNotification(notificationTitle, notificationOptions);
  });
} catch (e) {
  // Safari iOS < 16.4 não suporta Push API via Service Worker.
  // Isolamos o erro para não impedir o carregamento do app.
  console.warn('[firebase-messaging-sw.js] Push API não suportada neste browser:', e);
}
