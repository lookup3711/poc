const express = require('express');
const axios = require('axios');
const app = express();

app.get('/', async (req, res) => {
  try {
    // ECSタスクからインターネットにアクセスして、自分のパブリックIPを取得
    const ipResponse = await axios.get('https://api.ipify.org?format=json');
    const response = {
      message: 'Hello from ECS! prd version!',
      publicIP: ipResponse.data.ip,
      puga: 'fuga',
    };
    console.log('External access successful:', response);
    res.json(response);
  } catch (error) {
    console.error('External access failed:', error.message);
    res.status(500).json({ error: 'Failed to access external network' });
  }
});

const port = process.env.PORT || 8080;
app.listen(port, () => {
  console.log(`App listening on port ${port}`);
});
