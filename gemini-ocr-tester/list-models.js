// Probes different Gemini model names to find which ones your project has access to
import { execSync } from 'child_process';

const projectId = 'gen-lang-client-0163553499';
const region = 'us-central1';

const modelsToTry = [
  'gemini-3.0-flash',
  'gemini-3.0-pro',
  'gemini-3.5-flash',
  'gemini-3.5-pro',
  'gemini-2.5-flash',
  'gemini-2.5-pro',
  'gemini-2.5-flash-preview-05-20',
  'gemini-2.0-flash',
  'gemini-2.0-flash-001',
  'gemini-2.0-flash-lite',
  'gemini-1.5-flash',
  'gemini-1.5-flash-002',
  'gemini-1.5-pro',
  'gemini-1.5-pro-002',
  'gemini-pro',
  'gemini-pro-vision',
];

async function main() {
  console.log('Getting access token...');
  const token = execSync('gcloud auth print-access-token', { encoding: 'utf8' }).trim();
  
  console.log(`\nProbing ${modelsToTry.length} model names on project "${projectId}" (${region})...\n`);
  
  const testBody = JSON.stringify({
    contents: [{ parts: [{ text: "Say hello" }] }]
  });

  for (const model of modelsToTry) {
    const url = `https://${region}-aiplatform.googleapis.com/v1/projects/${projectId}/locations/${region}/publishers/google/models/${model}:generateContent`;
    try {
      const res = await fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${token}` },
        body: testBody
      });
      const data = await res.json();
      if (res.ok) {
        console.log(`  ✅ ${model}  — WORKS!`);
      } else if (res.status === 404) {
        console.log(`  ❌ ${model}  — not found`);
      } else {
        console.log(`  ⚠️  ${model}  — ${res.status}: ${data?.error?.message?.substring(0, 80) || 'unknown'}`);
      }
    } catch (e) {
      console.log(`  ❌ ${model}  — fetch error: ${e.message}`);
    }
  }
  console.log('\nDone! Use any model marked with ✅ in the dropdown.');
}

main();
