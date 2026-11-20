// Cache the dashboard only. Live exchange-rate requests stay on the network.
const prefix='gtl-dashboard:'+self.registration.scope+':';
const cacheName=prefix+'v2-payroll-xlsx';
self.addEventListener('install',event=>{
  event.waitUntil(caches.open(cacheName).then(cache=>cache.addAll(['./index.html','./jszip.min.js','./manifest.webmanifest','./icon-192.png','./icon-512.png'].map(path=>new Request(path,{cache:'reload'})))).then(()=>self.skipWaiting()));
});
self.addEventListener('activate',event=>{
  event.waitUntil(caches.keys().then(keys=>Promise.all(keys.filter(key=>key.startsWith(prefix)&&key!==cacheName).map(key=>caches.delete(key)))).then(()=>self.clients.claim()));
});
self.addEventListener('fetch',event=>{
  const url=new URL(event.request.url);
  const scope=new URL(self.registration.scope);
  if(event.request.mode!=='navigate'||url.origin!==scope.origin||![scope.pathname,scope.pathname+'index.html'].includes(url.pathname))return;
  event.respondWith(fetch(event.request).catch(async()=>await (await caches.open(cacheName)).match('./index.html')||Response.error()));
});
