const express = require('express');
const app = express();
const PORT = 8080;

app.get('/', (req, res) => {
  res.send('<h1>Hello! This is Heshan Thilakawardena.</h1>');
});

app.get('/health', (req, res) => {
  res.status(200).send('OK');
});

app.listen(PORT, () => {
  console.log(`App running on port ${PORT}`);
});