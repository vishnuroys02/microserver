const express = require('express');
const app = express();
app.get('/health', (req, res) => res.json({ status: 'UP', service: 'product' }));
app.get('/product', (req, res) => res.json({ message: 'Hello from product service' }));
app.listen(3000, () => console.log('product service running on 3000'));
