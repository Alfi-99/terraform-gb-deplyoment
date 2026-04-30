const express = require('express');
const app = express();
const port = process.env.PORT || 8080;

// Root route agar Load Balancer senang
app.get('/', (req, res) => {
  res.status(200).send('Koperasi Merah Putih - App is running');
});

// Health check route
app.get('/health', (req, res) => {
  res.status(200).json({ 
    status: 'healthy', 
    environment: process.env.DEPLOYMENT_COLOR || 'unknown',
    timestamp: new Date().toISOString()
  });
});

app.listen(port, () => {
  console.log(`Server running on port ${port}`);
});
