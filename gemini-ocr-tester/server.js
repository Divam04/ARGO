import http from 'http';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const PORT = process.env.PORT || 3050;

const MIME_TYPES = {
  '.html': 'text/html',
  '.css': 'text/css',
  '.js': 'text/javascript',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.svg': 'image/svg+xml',
  '.json': 'application/json'
};

/**
 * Calls the Gemini API using the correct endpoint based on auth type.
 *
 * Path A — Vertex AI (Enterprise):
 *   Uses aiplatform.googleapis.com with OAuth2 Bearer token (ya29...).
 *   Requires projectId and region.
 *
 * Path B — AI Studio (Developer):
 *   Uses generativelanguage.googleapis.com with API key (AIzaSy...) as query param.
 */
async function callGeminiAPI({ credential, model, prompt, base64Data, mimeType, projectId, region }) {
  const requestBody = {
    contents: [
      {
        role: "user",
        parts: [
          { text: prompt },
          { inline_data: { mime_type: mimeType, data: base64Data } }
        ]
      }
    ],
    generationConfig: {
      response_mime_type: "application/json"
    }
  };

  let url, headers;
  const cred = credential.trim();

  // Decide which endpoint to use
  const useVertexAI = cred.startsWith('ya29') || (projectId && !cred.startsWith('AIza'));

  if (useVertexAI) {
    // ─── Path A: Vertex AI endpoint ───
    if (!projectId) {
      throw new Error(
        'Project ID is required for Vertex AI / OAuth2 auth. ' +
        'Please fill in the "☁️ Project ID" field in the top config bar. ' +
        'You can find your project ID by running: gcloud config get-value project'
      );
    }
    const loc = region || 'us-central1';
    url = `https://${loc}-aiplatform.googleapis.com/v1/projects/${projectId}/locations/${loc}/publishers/google/models/${model}:generateContent`;
    headers = {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${cred}`
    };
    console.log(`[OCR Auth] Using Vertex AI endpoint (${loc}) with OAuth2 token`);
    console.log(`[OCR Auth] Project: ${projectId} | Model: ${model}`);
  } else {
    // ─── Path B: AI Studio endpoint ───
    url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${cred}`;
    headers = { 'Content-Type': 'application/json' };
    console.log(`[OCR Auth] Using AI Studio endpoint with API key`);
    console.log(`[OCR Auth] Model: ${model}`);
  }

  const response = await fetch(url, {
    method: 'POST',
    headers,
    body: JSON.stringify(requestBody)
  });

  const data = await response.json();

  if (!response.ok) {
    console.error('[OCR API Error]', JSON.stringify(data?.error || data, null, 2));
    const msg = data?.error?.message || JSON.stringify(data);

    // Provide helpful hints for common errors
    if (msg.includes('OAuth2') || msg.includes('API keys are not supported')) {
      throw new Error(
        'Your project requires OAuth2 auth. Run this in your terminal:\n' +
        '  gcloud auth print-access-token\n' +
        'Paste the ya29... output into the Credential box. Also fill in your Project ID.'
      );
    }
    if (msg.includes('insufficient authentication scopes')) {
      throw new Error(
        'Insufficient scopes. Try regenerating your token with:\n' +
        '  gcloud auth application-default login\n' +
        '  gcloud auth application-default print-access-token\n' +
        'Or ensure you are using the Vertex AI endpoint (fill in Project ID and Region).'
      );
    }
    if (msg.includes('PERMISSION_DENIED') || msg.includes('permission')) {
      throw new Error(
        `Permission denied (${response.status}). Ensure:\n` +
        '1. The "Vertex AI API" is enabled in your Google Cloud project\n' +
        '2. Your account has the "Vertex AI User" role\n' +
        `3. Your project ID (${projectId}) is correct\n` +
        `Original: ${msg}`
      );
    }

    throw new Error(`Gemini API error (${response.status}): ${msg}`);
  }

  const text = data?.candidates?.[0]?.content?.parts?.[0]?.text;
  if (!text) {
    throw new Error('No text returned from Gemini. Full response: ' + JSON.stringify(data));
  }
  return text;
}

const server = http.createServer(async (req, res) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    res.writeHead(204);
    return res.end();
  }

  if (req.url === '/api/scan-label' && req.method === 'POST') {
    let body = '';
    req.on('data', chunk => { body += chunk.toString(); });
    req.on('end', async () => {
      try {
        const {
          image,
          apiKey: clientCred,
          model: selectedModel = 'gemini-2.5-flash',
          projectId: clientProjectId,
          region: clientRegion
        } = JSON.parse(body);

        let credential = (clientCred || process.env.GEMINI_API_KEY || '').trim().replace(/^["']|["']$/g, '');
        if (!credential) {
          res.writeHead(400, { 'Content-Type': 'application/json' });
          return res.end(JSON.stringify({
            error: 'Missing credential. Paste your ya29... OAuth token or AIzaSy... API key in the Credential box.'
          }));
        }

        if (!image) {
          res.writeHead(400, { 'Content-Type': 'application/json' });
          return res.end(JSON.stringify({ error: 'No image data provided.' }));
        }

        const base64Data = image.includes(',') ? image.split(',')[1] : image;
        const mimeTypeMatch = image.match(/data:([a-zA-Z0-9]+\/[a-zA-Z0-9-.+]+).*,.*/);
        const mimeType = mimeTypeMatch ? mimeTypeMatch[1] : 'image/png';

        const projectId = clientProjectId || process.env.GOOGLE_CLOUD_PROJECT || '';
        const region = clientRegion || process.env.GOOGLE_CLOUD_REGION || 'us-central1';

        const prompt = `Analyze this shipping label or parcel tag. Extract the following fields as a valid JSON object with exactly these keys:
- recipientName: The full name of the person receiving the package.
- trackingNumber: The AWB, tracking, or order number.
- courierCompany: The shipping carrier (e.g., Amazon, BlueDart, FedEx, DHL, USPS, UPS).
- phoneNumber: Any contact phone number listed for the recipient.
- address: The full destination address visible on the label.
- senderName: The sender or merchant name if visible.
If a field is not found, set its value to null. Return ONLY valid JSON, no extra text.`;

        const startTime = Date.now();
        const responseText = await callGeminiAPI({
          credential, model: selectedModel, prompt, base64Data, mimeType, projectId, region
        });
        const duration = Date.now() - startTime;

        let parsedJson;
        try {
          parsedJson = JSON.parse(responseText);
        } catch {
          const match = responseText.match(/\{[\s\S]*\}/);
          if (match) parsedJson = JSON.parse(match[0]);
          else throw new Error('Could not parse JSON from Gemini response: ' + responseText);
        }

        console.log(`[OCR Success] Done in ${duration}ms →`, parsedJson);
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ success: true, durationMs: duration, data: parsedJson }));

      } catch (error) {
        console.error('[OCR Error]', error.message);
        res.writeHead(500, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: error.message || 'Failed to scan label' }));
      }
    });
    return;
  }

  // Serve static files from public/
  let filePath = req.url === '/' ? '/index.html' : req.url;
  filePath = path.join(__dirname, 'public', filePath);

  const extname = String(path.extname(filePath)).toLowerCase();
  const contentType = MIME_TYPES[extname] || 'application/octet-stream';

  fs.readFile(filePath, (error, content) => {
    if (error) {
      res.writeHead(error.code === 'ENOENT' ? 404 : 500, { 'Content-Type': 'text/html' });
      res.end(`<h1>${error.code === 'ENOENT' ? '404 Not Found' : 'Server Error: ' + error.code}</h1>`);
    } else {
      res.writeHead(200, { 'Content-Type': contentType });
      res.end(content, 'utf-8');
    }
  });
});

server.listen(PORT, () => {
  console.log(`\n🚀 [Gemini OCR Sandbox] Server running at http://localhost:${PORT}/`);
  console.log(`\n📋 Quick Setup Guide:`);
  console.log(`   1. Run in another terminal:  gcloud auth print-access-token`);
  console.log(`   2. Paste the ya29... token into the "Credential" box on the webpage`);
  console.log(`   3. Run:  gcloud config get-value project`);
  console.log(`   4. Paste the project ID into the "Project ID" box on the webpage`);
  console.log(`   5. Select a label preset and click "Scan Label with Gemini Vision"!\n`);
});
