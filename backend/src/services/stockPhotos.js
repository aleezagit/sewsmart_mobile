const config = require('../config');

// Real photos for designs, found by searching Pexels (pexels.com/api, free key).
// Without PEXELS_API_KEY, or when Pexels does not answer, there are no photos and
// the apps show their icons instead. A failure never stops what the caller is doing.
async function searchPhotos(query, count) {
  if (!config.pexelsApiKey) return [];
  try {
    const url = new URL('https://api.pexels.com/v1/search');
    url.search = new URLSearchParams({ query, per_page: String(Math.min(Math.max(count, 1), 80)), orientation: 'portrait' }).toString();
    const response = await fetch(url, { headers: { Authorization: config.pexelsApiKey }, signal: AbortSignal.timeout(8000) });
    if (!response.ok) {
      console.error(`Pexels refused the search "${query}" (${response.status})`);
      return [];
    }
    const { photos = [] } = await response.json();
    return photos.map((photo) => photo.src?.portrait || photo.src?.large).filter(Boolean);
  } catch (error) {
    console.error(`Pexels search "${query}" failed: ${error.message}`);
    return [];
  }
}

module.exports = { searchPhotos };
