const express = require('express');
const app = express();

app.get('/', (req, res) => {
  res.send('Hello from ECS!');
});

const port = process.env.PORT || 80;
app.listen(port, () => {
  console.log(`App listening on port ${port}`);
});
