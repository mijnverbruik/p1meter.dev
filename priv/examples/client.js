const net = require('net');

const client = new net.Socket();
client.connect(8080, 'p1meter.dev', () => {
  console.log('Connected to Smart Meter P1 Stream');
});

client.on('data', (data) => {
  // Raw telegram data (DSMR 5.0 format)
  console.log(data.toString());
});

client.on('close', () => {
  console.log('Connection closed');
});
