const fs = require('fs');
const path = require('path');
const config = require('../config');
const { HttpError } = require('../utils/errors');

// Sends the photo to the Flask try-on service (tryon-service/) and saves the
// image it returns next to the other uploads. Returns the saved file path.
async function renderTryOn(photoPath, garmentType, command, outputDir) {
  if (!config.tryOnServiceUrl) throw new HttpError(503, 'The virtual try-on service is not available right now');
  const form = new FormData();
  form.append('photo', new Blob([await fs.promises.readFile(photoPath)]), path.basename(photoPath));
  form.append('garment_type', garmentType);
  if (command) form.append('command', command);

  let response;
  try {
    response = await fetch(`${config.tryOnServiceUrl}/try-on`, { method: 'POST', body: form, signal: AbortSignal.timeout(60000) });
  } catch {
    throw new HttpError(503, 'The virtual try-on service is not available right now');
  }
  if (response.status === 400) throw new HttpError(400, 'The photo could not be read. Try a clearer full-body photo');
  if (!response.ok) throw new HttpError(502, 'The virtual try-on failed. Please try again');

  const output = path.join(outputDir, `${path.parse(photoPath).name}-result.png`);
  await fs.promises.writeFile(output, Buffer.from(await response.arrayBuffer()));
  return output;
}

module.exports = { renderTryOn };
