const config = require('../config');

// Real photos for designs, found by searching Pixabay (pixabay.com/api/docs, free key).
// Without PIXABAY_API_KEY, or when Pixabay does not answer, there are no photos and
// the apps show their icons instead. A failure never stops what the caller is doing.
async function searchPhotos(query, count) {
  if (!config.pixabayApiKey) return [];
  try {
    const url = new URL('https://pixabay.com/api/');
    url.search = new URLSearchParams({
      key: config.pixabayApiKey,
      q: query.slice(0, 100),
      image_type: 'photo',
      orientation: 'vertical',
      category: 'fashion',
      safesearch: 'true',
      per_page: String(Math.min(Math.max(count, 3), 200)),
    }).toString();
    const response = await fetch(url, { headers: { accept: 'application/json' }, signal: AbortSignal.timeout(8000) });
    if (!response.ok) {
      console.error(`Pixabay refused the search "${query}" (${response.status})`);
      return [];
    }
    const { hits = [] } = await response.json();
    return hits.map((hit) => hit.webformatURL).filter(Boolean);
  } catch (error) {
    console.error(`Pixabay search "${query}" failed: ${error.message}`);
    return [];
  }
}

module.exports = { searchPhotos };
