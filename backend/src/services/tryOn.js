const fs = require('fs');
const path = require('path');
const config = require('../config');
const { HttpError } = require('../utils/errors');

// The try-on model needs up to a minute, and a busy one more.
const TIMEOUT_MS = 170000;

// Sends the person's photo and the garment photo to the Flask try-on service
// (tryon-service/) and saves the image it returns next to the other uploads.
// Returns the saved file path.
async function renderTryOn(photoPath, garmentPath, garmentType, command, outputDir) {
  if (!config.tryOnServiceUrl) throw new HttpError(503, 'The virtual try-on service is not available right now');
  const form = new FormData();
  form.append('photo', new Blob([await fs.promises.readFile(photoPath)]), path.basename(photoPath));
  form.append('garment', new Blob([await fs.promises.readFile(garmentPath)]), path.basename(garmentPath));
  form.append('garment_type', garmentType);
  if (command) form.append('command', command);

  let response;
  try {
    response = await fetch(`${config.tryOnServiceUrl}/try-on`, { method: 'POST', body: form, signal: AbortSignal.timeout(TIMEOUT_MS) });
  } catch (error) {
    if (error.name === 'TimeoutError') throw new HttpError(504, 'The try-on took too long. Please try again');
    throw new HttpError(503, 'The virtual try-on service is not available right now');
  }
  if (!response.ok) {
    // The service writes messages meant for the customer.
    const { message } = await response.json().catch(() => ({}));
    const known = [400, 502, 503, 504].includes(response.status);
    throw new HttpError(known ? response.status : 502, message || 'The virtual try-on failed. Please try again');
  }

  const output = path.join(outputDir, `${path.parse(photoPath).name}-result.png`);
  await fs.promises.writeFile(output, Buffer.from(await response.arrayBuffer()));
  return output;
}

module.exports = { renderTryOn };
