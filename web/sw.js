// 云助通Web主控端 - Service Worker（开发环境优化版）
// 版本号，更新时递增以强制更新缓存
const CACHE_VERSION = 'v1.0.1';
const CACHE_NAME = `yunzhutong-cache-${CACHE_VERSION}`;

// 检测是否为开发环境
const isDevelopment = location.hostname === 'localhost' || location.hostname === '127.0.0.1';

// 关键资源预缓存列表（仅生产环境资源）
const PRECACHE_RESOURCES = [
  '/',
  '/manifest.json',
  '/favicon.png'
];

// 动态缓存的资源类型
const RUNTIME_CACHE_PATTERNS = [
  /\.(?:js|css|html)$/,
  /\.(?:png|jpg|jpeg|svg|gif|webp)$/,
  /\.(?:woff|woff2|ttf|otf)$/,
  /\.(?:json|wasm)$/
];

// 安装事件 - 预缓存关键资源
self.addEventListener('install', event => {
  console.log('Service Worker: 安装中...');
  
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then(cache => {
        console.log('Service Worker: 预缓存关键资源');
        return cache.addAll(PRECACHE_RESOURCES);
      })
      .then(() => {
        console.log('Service Worker: 安装完成');
        // 强制激活新的Service Worker
        return self.skipWaiting();
      })
      .catch(error => {
        console.error('Service Worker: 预缓存失败', error);
      })
  );
});

// 激活事件 - 清理旧缓存
self.addEventListener('activate', event => {
  console.log('Service Worker: 激活中...');
  
  event.waitUntil(
    caches.keys()
      .then(cacheNames => {
        return Promise.all(
          cacheNames
            .filter(cacheName => {
              // 删除不匹配当前版本的缓存
              return cacheName.startsWith('yunzhutong-cache-') && 
                     cacheName !== CACHE_NAME;
            })
            .map(cacheName => {
              console.log('Service Worker: 删除旧缓存', cacheName);
              return caches.delete(cacheName);
            })
        );
      })
      .then(() => {
        console.log('Service Worker: 激活完成');
        // 立即控制所有客户端
        return self.clients.claim();
      })
  );
});

// 拦截网络请求
self.addEventListener('fetch', event => {
  const { request } = event;
  const url = new URL(request.url);
  
  // 只处理同源请求
  if (url.origin !== location.origin) {
    return;
  }
  
  // 忽略非GET请求
  if (request.method !== 'GET') {
    return;
  }
  
  // 开发环境：避免处理Flutter相关资源，让默认SW处理
  if (isDevelopment) {
    const skipPaths = [
      '/main.dart.js',
      '/flutter_service_worker.js',
      '/canvaskit/',
      '/flutter_bootstrap.js',
      '.dart.js',
      '.dart.wasm'
    ];
    
    if (skipPaths.some(path => url.pathname.includes(path))) {
      return; // 让默认处理器处理
    }
  }
  
  event.respondWith(
    handleRequest(request)
  );
});

// 处理请求的策略（简化版）
async function handleRequest(request) {
  const url = new URL(request.url);
  
  try {
    // 开发环境：简化策略，优先使用网络
    if (isDevelopment) {
      return await networkFirstSimple(request);
    }
    
    // 生产环境：根据资源类型选择策略
    if (url.pathname.endsWith('.html') || url.pathname === '/') {
      return await networkFirstSimple(request);
    }
    
    if (RUNTIME_CACHE_PATTERNS.some(pattern => pattern.test(url.pathname))) {
      return await cacheFirstSafe(request);
    }
    
    // 默认：网络优先
    return await networkFirstSimple(request);
    
  } catch (error) {
    console.warn('Service Worker: 请求处理失败', error.message);
    // 直接从网络获取，不返回错误响应
    return fetch(request);
  }
}

// 简化的网络优先策略
async function networkFirstSimple(request) {
  try {
    const response = await fetch(request);
    
    // 只缓存成功的响应
    if (response.ok && !isDevelopment) {
      try {
        const cache = await caches.open(CACHE_NAME);
        cache.put(request, response.clone()).catch(() => {
          // 静默忽略缓存错误
        });
      } catch (e) {
        // 静默忽略缓存错误
      }
    }
    
    return response;
  } catch (error) {
    // 网络失败，尝试缓存
    if (!isDevelopment) {
      const cachedResponse = await caches.match(request);
      if (cachedResponse) {
        return cachedResponse;
      }
    }
    throw error;
  }
}

// 安全的缓存优先策略
async function cacheFirstSafe(request) {
  try {
    const cachedResponse = await caches.match(request);
    if (cachedResponse) {
      return cachedResponse;
    }
  } catch (e) {
    // 缓存读取失败，直接从网络获取
  }
  
  return await networkFirstSimple(request);
}

// 简化的缓存管理（移除复杂逻辑）

// 监听消息事件
self.addEventListener('message', event => {
  if (event.data && event.data.type === 'SKIP_WAITING') {
    self.skipWaiting();
  }
  
  if (event.data && event.data.type === 'CACHE_CLEAR') {
    // 清除所有缓存
    caches.keys().then(cacheNames => {
      return Promise.all(
        cacheNames.map(cacheName => caches.delete(cacheName))
      );
    }).then(() => {
      console.log('Service Worker: 所有缓存已清除');
    });
  }
});

// 错误处理
self.addEventListener('error', event => {
  console.error('Service Worker: 发生错误', event.error);
});

self.addEventListener('unhandledrejection', event => {
  console.error('Service Worker: 未处理的Promise拒绝', event.reason);
}); 