const bcrypt = require('bcryptjs');
const config = require('../config');
const Admin = require('../models/Admin');
const Settings = require('../models/Settings');
const Design = require('../models/Design');
const DESIGNS = require('../data/designs');
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
// Designs without a photo get one from Pexels, a different one each, when a key
// is set; the others are retried at the next start. Safe to run at every start-up.
async function ensureCatalogue() {
  for (const [i, [name, category, min, max]] of DESIGNS.entries()) {
    const tags = [...new Set(name.toLowerCase().match(/[a-z]+/g))];
    await Design.updateOne({ _id: `D${String(i + 1).padStart(3, '0')}` }, { name, category, price_min: min, price_max: max, tags }, { upsert: true });
  }
  // An earlier version pointed at a picture service that no longer answers.
  await Design.updateMany({ image_url: /pollinations/ }, { image_url: null });
  if (!config.pexelsApiKey) return;
  const used = new Set((await Design.find({ image_url: { $ne: null } })).map((d) => d.image_url));
  for (const design of await Design.find({ image_url: null }).sort({ _id: 1 })) {
    const photo = (await searchPhotos(`${design.name} ${design.category} dress`, 10)).find((url) => !used.has(url));
    if (!photo) continue;
    used.add(photo);
    await Design.updateOne({ _id: design.id }, { image_url: photo });
  }
}

module.exports = { ensureAdmin, ensureCatalogue };
