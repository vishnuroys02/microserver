const express = require('express');
const app = express();
app.get('/health', (req, res) => res.json({ status: 'UP', service: 'user' }));
app.get('/user', (req, res) => res.json({ message: 'Hello from user service' }));
app.listen(3000, () => console.log('user service running on 3000'));
