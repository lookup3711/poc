const express = require('express');
const axios = require('axios');
const { Client } = require('pg');
const app = express();

app.get('/', async (req, res) => {
  try {
    const ipResponse = await axios.get('https://api.ipify.org?format=json');
    const response = {
      message: 'Hello from ECS!',
      publicIP: ipResponse.data.ip,
      env: process.env.ENV || "unknown",
      version: process.env.APP_VERSION || "unknown",
    };
    console.log('External access successful:', response);
    res.json(response);
  } catch (error) {
    console.error('External access failed:', error.message);
    res.status(500).json({ error: 'Failed to access external network' });
  }
});

app.get('/env', (req, res) => {
  const keys = ['POSTGRES_HOST', 'POSTGRES_PORT', 'POSTGRES_USER', 'POSTGRES_PASSWORD', 'POSTGRES_DB'];
  const result = {};
  keys.forEach(k => result[k] = process.env[k] || null);
  res.json(result);
});

// ✅ DB 接続確認用エンドポイント
app.get('/db-check', async (req, res) => {
  const client = new Client({
    host: process.env.POSTGRES_HOST,
    port: Number(process.env.POSTGRES_PORT),
    user: process.env.POSTGRES_USER,
    password: process.env.POSTGRES_PASSWORD,
    database: process.env.POSTGRES_DB,
    ssl: {
      rejectUnauthorized: false
    }
  });

  try {
    await client.connect();
    const result = await client.query('SELECT NOW() AS now');
    await client.end();
    res.json({ dbStatus: 'connected', timestamp: result.rows[0].now });
  } catch (err) {
    console.error('DB connection failed:', err.message);
    res.status(500).json({ dbStatus: 'error', error: err.message });
  }
});


const port = process.env.PORT || 8080;
app.listen(port, () => {
  console.log(`App listening on port ${port}`);
});
