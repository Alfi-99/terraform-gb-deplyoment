const http = require('http');
const server = http.createServer((req, res) => {
  if (req.url === '/health') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ status: 'healthy' }));
  } else {
    res.writeHead(200);
    res.end('Hello from Blue/Green App!');
  }
});
server.listen(process.env.PORT || 8080);
console.log('Server running on port', process.env.PORT || 8080);
