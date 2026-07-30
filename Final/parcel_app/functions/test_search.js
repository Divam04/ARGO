const https = require('https');

const data = JSON.stringify({
  data: {
    recipientName: "a"
  }
});

const options = {
  hostname: 'us-central1-argo-parcel-app-backend.cloudfunctions.net',
  path: '/resolveStudentMatch',
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
