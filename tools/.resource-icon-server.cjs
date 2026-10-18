const http = require('http'), fs = require('fs'), path = require('path');
const root = path.resolve('assets/icons/resources');
http.createServer((q,s) => {
 const n = path.basename(decodeURIComponent(q.url));
 fs.readFile(path.join(root,n), (e,b) => { s.writeHead(e?404:200, {'Content-Type':'image/png'}); s.end(e?'missing':b); });
}).listen(8766,'127.0.0.1');
