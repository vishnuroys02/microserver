const express = require('express');
const app = express();
app.get('/health', (req, res) => res.json({ status: 'UP', service: 'order' }));
app.get('/order', (req, res) => res.json({ message: 'Hello from order service' }));
app.listen(3000, () => console.log('order service running on 3000'));
