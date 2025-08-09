const CACHE_NAME = 'doglog-v1.0.0';
const urlsToCache = [
  '/doglog-full-demo.html',
  '/manifest.json',
  // Add other assets as needed
];

// Install event - cache resources
self.addEventListener('install', event => {
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then(cache => {
        console.log('🐕 DogLog: Cache opened');
        return cache.addAll(urlsToCache);
      })
      .catch(err => {
        console.log('🐕 DogLog: Cache failed', err);
      })
  );
  // Skip waiting to activate immediately
  self.skipWaiting();
});

// Activate event - clean up old caches
self.addEventListener('activate', event => {
  event.waitUntil(
    caches.keys().then(cacheNames => {
      return Promise.all(
        cacheNames.map(cacheName => {
          if (cacheName !== CACHE_NAME) {
            console.log('🐕 DogLog: Deleting old cache', cacheName);
            return caches.delete(cacheName);
          }
        })
      );
    })
  );
  // Take control of all pages immediately
  self.clients.claim();
});

// Fetch event - serve from cache with network fallback
self.addEventListener('fetch', event => {
  event.respondWith(
    caches.match(event.request)
      .then(response => {
        // Return cached version or fetch from network
        return response || fetch(event.request);
      })
      .catch(() => {
        // Fallback for offline navigation
        if (event.request.destination === 'document') {
          return caches.match('/doglog-full-demo.html');
        }
      })
  );
});

// Background sync for data when coming back online
self.addEventListener('sync', event => {
  if (event.tag === 'background-sync') {
    console.log('🐕 DogLog: Background sync triggered');
    // Here you could sync local data to server when back online
  }
});

// Push notification support for future features
self.addEventListener('push', event => {
  if (event.data) {
    const data = event.data.json();
    const options = {
      body: data.body,
      icon: '/icons/icon-192x192.png',
      badge: '/icons/icon-72x72.png',
      data: data.data || {}
    };
    
    event.waitUntil(
      self.registration.showNotification(data.title, options)
    );
  }
});

// Notification click handling
self.addEventListener('notificationclick', event => {
  event.notification.close();
  
  event.waitUntil(
    clients.openWindow('/doglog-full-demo.html')
  );
});