/* ══════════════════════════════════════════════════════════════
   صيدلية العصافرة — Service Worker (PWA)
   نسخة احترافية لدعم تثبيت الموقع كتطبيق على الهاتف والأجهزة المحمولة
   ══════════════════════════════════════════════════════════════ */

const CACHE_NAME = 'asafra-pwa-v1.0.3';

// الأصول الأساسية لهيكل التطبيق (App Shell)
const PRECACHE_ASSETS = [
  '/',
  '/index.html',
  '/manifest.webmanifest',
  '/icons/icon-192.png',
  '/icons/icon-512.png',
  '/icons/icon-maskable-192.png',
  '/icons/icon-maskable-512.png',
  '/icons/icon.svg',
  '/icons/apple-touch-icon.png',
  '/icons/favicon-32.png'
];

// روابط وخوادم البيانات الحية التي يمنع تخزينها مؤقتاً لضمان دقة الحسابات اللحظية
const NETWORK_ONLY_HOSTS = [
  'supabase.co',
  'googleapis.com',
  'identitytoolkit.googleapis.com',
  'securetoken.googleapis.com',
  'firebaseio.com'
];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => {
      return cache.addAll(PRECACHE_ASSETS).catch((err) => {
        console.warn('[SW] Pre-caching partial failure (safe to continue):', err);
      });
    })
  );
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((cacheNames) => {
      return Promise.all(
        cacheNames.map((name) => {
          if (name !== CACHE_NAME) {
            console.log('[SW] Deleting old cache:', name);
            return caches.delete(name);
          }
        })
      );
    }).then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', (event) => {
  const req = event.request;
  const url = new URL(req.url);

  // الطلبات غير طلبات GET لا تتدخل فيها
  if (req.method !== 'GET') return;

  // منع التدخل في خوادم Supabase أو Firebase الحية لضمان سلامة ومطابقة الأرصدة 100%
  const isLiveApi = NETWORK_ONLY_HOSTS.some(host => url.hostname.includes(host));
  if (isLiveApi) {
    return; // Pass through straight to network
  }

  // لصفحات التنقل (HTML Documents): نعتمد Network-First مع الرجوع للكاش عند انقطاع النت
  if (req.mode === 'navigate' || req.destination === 'document') {
    event.respondWith(
      fetch(req)
        .then((networkRes) => {
          if (networkRes && networkRes.status === 200) {
            const clone = networkRes.clone();
            caches.open(CACHE_NAME).then((cache) => cache.put(req, clone));
          }
          return networkRes;
        })
        .catch(() => {
          return caches.match(req).then((cached) => cached || caches.match('/index.html'));
        })
    );
    return;
  }

  // لباقي الأصول الثابتة (أيقونات، خطوط، مكتبات): Stale-While-Revalidate
  event.respondWith(
    caches.match(req).then((cachedRes) => {
      const fetchPromise = fetch(req)
        .then((networkRes) => {
          if (networkRes && networkRes.status === 200) {
            const clone = networkRes.clone();
            caches.open(CACHE_NAME).then((cache) => cache.put(req, clone));
          }
          return networkRes;
        })
        .catch(() => null);

      return cachedRes || fetchPromise;
    })
  );
});

// دعم تحديث فوري للـ Service Worker عند إرسال أمر تخطي الانتظار
self.addEventListener('message', (event) => {
  if (event.data && event.data.action === 'skipWaiting') {
    self.skipWaiting();
  }
});
