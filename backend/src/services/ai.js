const Design = require('../models/Design');

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

// Designs most similar to the given queries, best first. Several queries (the
// customer's recent searches) share the places in the result.
async function recommend(queries, limit) {
  const designs = await Design.find();
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

// Four design concepts from a prompt and the picked style. Each concept takes
// the prompt's details in a different direction.
const STYLES = [
  { title: 'Classic Elegance', angle: 'traditional cut with balanced, refined detailing' },
  { title: 'Modern Twist', angle: 'contemporary silhouette with clean lines and a modern neckline' },
  { title: 'Royal Style', angle: 'rich, heavily worked finish with statement embellishment' },
  { title: 'Minimalist', angle: 'simple structure that lets the fabric and colour lead' },
];

function designConcepts({ prompt, category, color, fabric }) {
  const details = words(prompt).filter((w) => w.length > 3).slice(0, 6).join(', ');
  return STYLES.map(({ title, angle }) => ({
    title,
    description: `${color} ${fabric.toLowerCase()} ${category.toLowerCase()} outfit: ${angle}${details ? `. Inspired by: ${details}` : ''}.`,
  }));
}

module.exports = { categorize, recommend, designConcepts };
