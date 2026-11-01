const crypto = require('crypto');
const bcrypt = require('bcryptjs');
const config = require('../config');
const Admin = require('../models/Admin');
const Settings = require('../models/Settings');
const Design = require('../models/Design');
const { DESIGNS, ALIASES } = require('../data/designs');
const { embed, modelId } = require('./embeddings');
const { searchPhotos } = require('./stockPhotos');

// Makes sure a new database can be used: the platform settings exist and, when
// ADMIN_EMAIL and ADMIN_PASSWORD are set, the first admin account exists. A
// host with no shell, such as Render's free plan, relies on this at start-up.
// An existing admin is never changed.
async function ensureAdmin() {
  await Settings.current();
  if (await Admin.exists({})) return false;
  const { email, password } = config.admin;
  if (!email || !password) return false;
  await Admin.create({ _id: 'ad001', name: 'Admin', email, password_hash: await bcrypt.hash(password, 10) });
  console.log(`Admin created: ${email}`);
  return true;
}

// The design catalogue that AI recommendations and the wishlist draw from.
// Designs without a photo get one from Pixabay, a different one each, when a key
// is set; the others are retried at the next start. Safe to run at every start-up.
async function ensureCatalogue() {
  for (const [i, [name, category, min, max]] of DESIGNS.entries()) {
    const tags = [...new Set(name.toLowerCase().match(/[a-z]+/g))];
    await Design.updateOne({ _id: `D${String(i + 1).padStart(3, '0')}` }, { name, category, price_min: min, price_max: max, tags }, { upsert: true });
  }
  // An earlier version pointed at a picture service that no longer answers.
  await Design.updateMany({ image_url: /pollinations/ }, { image_url: null });
  await ensureEmbeddings();
  if (!config.pixabayApiKey) return;
  const used = new Set((await Design.find({ image_url: { $ne: null } })).map((d) => d.image_url));
  for (const design of await Design.find({ image_url: null }).sort({ _id: 1 })) {
    const photo = (await searchPhotos(`${design.name} ${design.category} dress`, 10)).find((url) => !used.has(url));
    if (!photo) continue;
    used.add(photo);
    await Design.updateOne({ _id: design.id }, { image_url: photo });
  }
}

const embeddingText = (design) => `${design.name}. ${design.category} wear. ${ALIASES[design.category]}. ${design.tags.join(' ')}`;
const embeddingKey = (design) => `${modelId()}|${crypto.createHash('sha1').update(embeddingText(design)).digest('hex').slice(0, 10)}`;

// Gives every design the embedding the AI recommendations compare searches with. A
// design is redone when its text or the model changed. Needs GEMINI_API_KEY; a
// failure leaves the designs as they are and recommendations use keywords.
async function ensureEmbeddings() {
  const stale = (await Design.find()).filter((d) => !d.embedding?.length || d.embedding_model !== embeddingKey(d));
  if (!stale.length) return;
  const vectors = await embed(stale.map(embeddingText), 'RETRIEVAL_DOCUMENT');
  if (!vectors) return;
  for (const [i, design] of stale.entries()) {
    await Design.updateOne({ _id: design.id }, { embedding: vectors[i], embedding_model: embeddingKey(design) });
  }
}

module.exports = { ensureAdmin, ensureCatalogue, ensureEmbeddings };
