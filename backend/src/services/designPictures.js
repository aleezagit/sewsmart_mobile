const config = require('../config');

// Draws a picture from a description with an image model on Replicate
// (replicate.com, pay per picture; Flux Schnell costs about a third of a cent).
// Gives { data, type }, or null without REPLICATE_API_TOKEN or when anything goes
// wrong. A failure never stops what the caller is doing.
const POLL_MS = 3000;
const MAX_POLLS = 20;
const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

async function drawPicture(prompt) {
  const token = config.replicateApiToken;
  if (!token) return null;
  const headers = { Authorization: `Bearer ${token}`, 'content-type': 'application/json' };
  try {
    const started = await fetch(`https://api.replicate.com/v1/models/${config.imageModel}/predictions`, {
      method: 'POST',
      headers: { ...headers, Prefer: 'wait=60' },
      body: JSON.stringify({ input: { prompt, aspect_ratio: '3:4', num_outputs: 1, output_format: 'webp', output_quality: 80 } }),
      signal: AbortSignal.timeout(90000),
    });
    if (!started.ok) {
      console.error(`Replicate refused the picture "${prompt}" (${started.status}): ${await started.text()}`);
      return null;
    }
    let prediction = await started.json();
    for (let i = 0; prediction.status !== 'succeeded' && i < MAX_POLLS; i += 1) {
      if (['failed', 'canceled'].includes(prediction.status)) break;
      await sleep(POLL_MS);
      const polled = await fetch(prediction.urls.get, { headers, signal: AbortSignal.timeout(20000) });
      if (!polled.ok) break;
      prediction = await polled.json();
    }
    if (prediction.status !== 'succeeded') {
      console.error(`Replicate did not finish the picture "${prompt}" (${prediction.status}): ${prediction.error || ''}`);
      return null;
    }
    const link = Array.isArray(prediction.output) ? prediction.output[0] : prediction.output;
    const download = await fetch(link, { signal: AbortSignal.timeout(30000) });
    if (!download.ok) return null;
    return { data: Buffer.from(await download.arrayBuffer()), type: download.headers.get('content-type') || 'image/webp' };
  } catch (error) {
    console.error(`Replicate picture "${prompt}" failed: ${error.message}`);
    return null;
  }
}

module.exports = { drawPicture };
