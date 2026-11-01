const config = require('../config');

// A picture for a design, drawn by a text-to-image service from the description.
// The address holds everything the service needs, so nothing is stored here: the
// same description and seed always give the same picture, and the app loads it
// straight from the service.
function designImageUrl(description, seed) {
  const prompt = `${description}, fashion design photo, full length outfit, plain studio background, high detail`;
  const query = new URLSearchParams({ width: '512', height: '768', seed: String(seed), nologo: 'true', model: 'flux' });
  return `${config.imageApiUrl}/${encodeURIComponent(prompt)}?${query}`;
}

module.exports = { designImageUrl };
