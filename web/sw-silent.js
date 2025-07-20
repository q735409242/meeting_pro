// 云助通Web主控端 - 静默版Service Worker
const CACHE_VERSION = 'v1.0.1';
const CACHE_NAME = `yunzhutong-cache-${CACHE_VERSION}`;

// 检测是否为开发环境
const isDevelopment = location.hostname === 'localhost' || location.hostname === '127.0.0.1';

// 静默日志函数 - 不输出任何内容
const silentLog = () => {};
const silentWarn = () => {};
const silentError = () => {};

// 关键资源预缓存列表（仅生产环境资源）
const PRECACHE_RESOURCES = [
  '/',
  '/manifest.json',
  '/favicon.png'
];

// 运行时缓存的文件类型
const RUNTIME_CACHE_PATTERNS = [
  /\.js$/,
  /\.css$/,
  /\.png$/,
  /\.jpg$/,
  /\.jpeg$/,
  /\.gif$/,
  /\.svg$/,
  /\.woff$/,
  /\.woff2$/,
  /\.ttf$/,
  /\.otf$/,
  /\.ico$/,
  /\.webp$/
];

// 安装事件
self.addEventListener('install', event => {
  event.waitUntil(
    caches.open(CACHE_NAME).then(cache => {
      return cache.addAll(PRECACHE_RESOURCES);
    }).catch(() => {
      // 静默忽略错误
    })
  );
  self.skipWaiting();
});

// 激活事件
self.addEventListener('activate', event => {
  event.waitUntil(
    caches.keys().then(cacheNames => {
      return Promise.all(
        cacheNames.map(cacheName => {
          if (cacheName !== CACHE_NAME) {
            return caches.delete(cacheName);
          }
        })
      );
    }).catch(() => {
      // 静默忽略错误
    })
  );
  self.clients.claim();
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
    // 直接从网络获取，不返回错误响应
    return fetch(request);
  }
}

// 消息处理
self.addEventListener('message', event => {
  if (event.data && event.data.type === 'SKIP_WAITING') {
    self.skipWaiting();
  }
});

// 错误处理 - 静默
self.addEventListener('error', event => {
  // 静默处理错误
});

self.addEventListener('unhandledrejection', event => {
  // 静默处理未捕获的Promise拒绝
}); 