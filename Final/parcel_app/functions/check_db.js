// We will make a direct HTTP request to the deployed Callable Function
const https = require('https');

const data = JSON.stringify({
  data: {
    pin: "4068",
    deviceId: "test_device",
    guardId: "test_guard"
  }
});

const options = {
  hostname: 'us-central1-argo-parcel-app-backend.cloudfunctions.net',
  path: '/resolvePin',
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Content-Length': data.length
  }
};

const req = https.request(options, (res) => {
  let responseData = '';
  res.on('data', (chunk) => {
    responseData += chunk;
  });
  res.on('end', () => {
    console.log('Status Code:', res.statusCode);
    console.log('Response:', responseData);
  });
});

req.on('error', (error) => {
  console.error('Error:', error);
});

req.write(data);
req.end();
