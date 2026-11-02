const Design = require('../models/Design');
const { embed, similarity, normalize } = require('./embeddings');

// Words that point to a design category. A query takes the category with the
// most matching words, or General when none match.
const CATEGORY_WORDS = {
  Bridal: ['bridal', 'bride', 'wedding', 'lehenga', 'nikkah', 'barat', 'walima', 'mehndi', 'dulhan', 'gharara', 'embroidery'],
  Formal: ['formal', 'shalwar', 'kameez', 'kurta', 'sherwani', 'executive', 'pajama', 'waistcoat'],
  Eastern: ['eastern', 'anarkali', 'suit', 'maxi', 'georgette', 'palazzo', 'silk', 'dupatta', 'abaya', 'sharara'],
  Casual: ['casual', 'lawn', 'summer', 'kids', 'cotton', 'lounge', 'comfy', 'everyday', 'frock'],
  Western: ['western', 'party', 'dress', 'short', 'jeans', 'denim', 'midi', 'jacket', 'blazer', 'trousers'],
};

const words = (text) => String(text || '').toLowerCase().match(/[a-z]+/g) || [];

function categorize(query) {
  const tokens = words(query);
  let best = 'General';
  let bestScore = 0;
  for (const [category, keywords] of Object.entries(CATEGORY_WORDS)) {
    const score = tokens.filter((token) => keywords.some((k) => token.startsWith(k) || (token.length > 3 && k.startsWith(token)))).length;
    if (score > bestScore) {
      best = category;
      bestScore = score;
    }
  }
  return best;
}

// Scores a design against query words: a word in the name counts most, then
// a tag, then the category.
function score(design, tokens, category) {
  const name = words(design.name);
  const tags = design.tags.map((t) => t.toLowerCase());
  let total = design.category === category ? 1 : 0;
  for (const token of tokens) {
    if (name.includes(token)) total += 3;
    if (tags.includes(token)) total += 2;
  }
  return total;
}

// Keyword matching: designs most similar to the given queries, best first. Several
// queries (the customer's recent searches) share the places in the result. This is
// what recommendations fall back to without embeddings.
function recommendByKeywords(designs, queries, limit) {
  if (!queries.length) return designs.slice(0, limit);
  const ranked = new Map();
  for (const query of queries) {
    const tokens = words(query);
    const category = categorize(query);
    for (const design of designs) {
      const value = score(design, tokens, category);
      if (value > 0) ranked.set(design.id, Math.max(ranked.get(design.id) || 0, value));
    }
  }
  return designs
    .filter((d) => ranked.has(d.id))
    .sort((a, b) => ranked.get(b.id) - ranked.get(a.id))
    .slice(0, limit);
}

// Each older search counts a little less than the one after it, and a saved design a bit less than a search.
const SEARCH_DECAY = 0.8;
const SAVED_WEIGHT = 0.7;

// The customer's taste as one vector: their recent searches (newest first) and
// the designs they saved, blended. Null when none of them has an embedding.
function tasteOf(searches, savedDesigns) {
  const parts = [
    ...searches.map((s, i) => ({ vector: s.embedding, weight: SEARCH_DECAY ** i })),
    ...savedDesigns.map((d) => ({ vector: d.embedding, weight: SAVED_WEIGHT })),
  ].filter((part) => part.vector?.length);
  if (!parts.length) return null;
  const sum = new Array(parts[0].vector.length).fill(0);
  for (const { vector, weight } of parts) vector.forEach((value, i) => { sum[i] += value * weight; });
  return normalize(sum);
}

// Designs for a search (`query`), or, without one, for the customer's own taste:
// their recent `searches` and `saved` design ids. Designs are ranked by how close
// their embedding is to the search or the taste. Without embeddings (no Gemini key,
// or Gemini not answering) the ranking is by keywords instead.
async function recommend({ query, searches, saved, limit }) {
  const designs = await Design.find();
  const keywordQueries = query ? [query] : searches.map((s) => s.query);
  if (!query && !searches.length && !saved.length) return designs.slice(0, limit);

  const embedded = designs.filter((d) => d.embedding?.length);
  let target = null;
  if (embedded.length) {
    target = query
      ? (await embed([query], 'RETRIEVAL_QUERY'))?.[0]
      : tasteOf(searches, embedded.filter((d) => saved.includes(d.id)));
  }
  if (!target) return recommendByKeywords(designs, keywordQueries, limit);

  return embedded
    .filter((d) => query || !saved.includes(d.id))
    .map((design) => ({ design, closeness: similarity(target, design.embedding) }))
    .sort((a, b) => b.closeness - a.closeness)
    .slice(0, limit)
    .map(({ design }) => design);
}

module.exports = { categorize, recommend };
