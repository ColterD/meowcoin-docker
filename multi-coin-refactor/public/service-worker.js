/**
 * Multi-Coin Blockchain Platform - Service Worker
 * Provides offline support and caching
 */

const CACHE_NAME = 'meowcoin-cache-v1';
const ASSETS_TO_CACHE = [
  '/',
  '/onboarding',
  '/styles.css',
  '/app.js',
  '/favicon.ico'
];

// Install event - cache assets
self.addEventListener('install', event => {
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then(cache => {
        console.log('Opened cache');
        return cache.addAll(ASSETS_TO_CACHE);
      })
      .then(() => self.skipWaiting())
  );
});

// Activate event - clean up old caches
self.addEventListener('activate', event => {
  const cacheWhitelist = [CACHE_NAME];
  
  event.waitUntil(
    caches.keys().then(cacheNames => {
      return Promise.all(
        cacheNames.map(cacheName => {
          if (cacheWhitelist.indexOf(cacheName) === -1) {
            return caches.delete(cacheName);
          }
        })
      );
    }).then(() => self.clients.claim())
  );
});

// Fetch event - serve from cache, fall back to network
self.addEventListener('fetch', event => {
  // Skip for API calls
  if (event.request.url.includes('/onboarding') && event.request.method === 'POST') {
    return;
  }
  
  if (event.request.url.includes('/feedback') && event.request.method === 'POST') {
    return;
  }
  
  event.respondWith(
    caches.match(event.request)
      .then(response => {
        // Cache hit - return response
        if (response) {
          return response;
        }
        
        // Clone the request
        const fetchRequest = event.request.clone();
        
        return fetch(fetchRequest).then(response => {
          // Check if valid response
          if (!response || response.status !== 200 || response.type !== 'basic') {
            return response;
          }
          
          // Clone the response
          const responseToCache = response.clone();
          
          caches.open(CACHE_NAME)
            .then(cache => {
              cache.put(event.request, responseToCache);
            });
            
          return response;
        });
      })
  );
});

// Handle offline form submissions
self.addEventListener('sync', event => {
  if (event.tag === 'onboarding-sync') {
    event.waitUntil(syncOnboardingData());
  } else if (event.tag === 'feedback-sync') {
    event.waitUntil(syncFeedbackData());
  }
});

// Sync onboarding data when back online
async function syncOnboardingData() {
  const db = await openDB();
  const pendingOnboarding = await db.getAll('pending-onboarding');
  
  for (const data of pendingOnboarding) {
    try {
      const response = await fetch('/onboarding', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify(data)
      });
      
      if (response.ok) {
        await db.delete('pending-onboarding', data.id);
      }
    } catch (error) {
      console.error('Failed to sync onboarding data:', error);
    }
  }
}

// Sync feedback data when back online
async function syncFeedbackData() {
  const db = await openDB();
  const pendingFeedback = await db.getAll('pending-feedback');
  
  for (const data of pendingFeedback) {
    try {
      const response = await fetch('/feedback', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify(data)
      });
      
      if (response.ok) {
        await db.delete('pending-feedback', data.id);
      }
    } catch (error) {
      console.error('Failed to sync feedback data:', error);
    }
  }
}

// Simple IndexedDB wrapper
function openDB() {
  return new Promise((resolve, reject) => {
    const request = indexedDB.open('meowcoin-offline-db', 1);
    
    request.onerror = () => reject(request.error);
    request.onsuccess = () => resolve(request.result);
    
    request.onupgradeneeded = () => {
      const db = request.result;
      if (!db.objectStoreNames.contains('pending-onboarding')) {
        db.createObjectStore('pending-onboarding', { keyPath: 'id', autoIncrement: true });
      }
      if (!db.objectStoreNames.contains('pending-feedback')) {
        db.createObjectStore('pending-feedback', { keyPath: 'id', autoIncrement: true });
      }
    };
  });
}