const crypto = require('crypto');
const bcrypt = require('bcryptjs');
const config = require('../config');
const Admin = require('../models/Admin');
const Settings = require('../models/Settings');
const Design = require('../models/Design');
const { DESIGNS, ALIASES } = require('../data/designs');
const { embed, modelId } = require('./embeddings');
const DesignPicture = require('../models/DesignPicture');
const { drawPicture } = require('./designPictures');

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

// The design catalogue that AI recommendations and the wishlist draw from. Quick, so
// the server can wait for it at start-up; ensureEmbeddings and ensurePictures need
// outside services and run in the background. Safe to run at every start-up.
async function ensureCatalogue() {
  for (const [i, [name, category, min, max]] of DESIGNS.entries()) {
    const tags = [...new Set(name.toLowerCase().match(/[a-z]+/g))];
    await Design.updateOne({ _id: `D${String(i + 1).padStart(3, '0')}` }, { name, category, price_min: min, price_max: max, tags }, { upsert: true });
  }
}

const pictureLink = (design, data) => `${config.publicUrl}/api/designs/${design.id}/image?v=${crypto.createHash('sha1').update(data).digest('hex').slice(0, 8)}`;
const picturePrompt = (design) => `${design.name}, ${design.category.toLowerCase()} wear, traditional Pakistani fashion, full-length outfit product photo on a plain studio background, high detail`;

// Draws a picture for every design that has none, when REPLICATE_API_TOKEN is set. The
// pictures are kept in the database; a design whose picture fails is tried again at the
// next start. Links to photos from earlier versions (which did not match the designs)
// are cleared, so a design shows its icon rather than a wrong picture.
async function ensurePictures() {
  await Design.updateMany({ image_url: { $ne: null, $not: /\/api\/designs\// } }, { image_url: null });
  if (!config.replicateApiToken) return;
  for (const design of await Design.find({ image_url: null }).sort({ _id: 1 })) {
    const picture = await drawPicture(picturePrompt(design));
    if (!picture) continue;
    await DesignPicture.updateOne({ _id: design.id }, { content_type: picture.type, data: picture.data }, { upsert: true });
    await Design.updateOne({ _id: design.id }, { image_url: pictureLink(design, picture.data) });
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

// What the catalogue gets from outside services. Failures are logged and retried at the next start.
function enrichCatalogue() {
  return ensureEmbeddings().then(ensurePictures).catch((error) => console.error(`Catalogue set-up failed: ${error.message}`));
}

module.exports = { ensureAdmin, ensureCatalogue, ensureEmbeddings, ensurePictures, enrichCatalogue };
