const bcrypt = require('bcryptjs');
const config = require('../config');
const Admin = require('../models/Admin');
const Settings = require('../models/Settings');
const Design = require('../models/Design');
const DESIGNS = require('../data/designs');
const { designImageUrl } = require('./designImages');

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

// The design catalogue that AI recommendations and the wishlist draw from, with
// a picture for each design. Safe to run at every start-up.
async function ensureCatalogue() {
  for (const [i, [name, category, min, max]] of DESIGNS.entries()) {
    const tags = [...new Set(name.toLowerCase().match(/[a-z]+/g))];
    await Design.updateOne(
      { _id: `D${String(i + 1).padStart(3, '0')}` },
      { name, category, price_min: min, price_max: max, tags, image_url: designImageUrl(`${name}, ${category} wear, Pakistani fashion`, 100 + i) },
      { upsert: true },
    );
  }
}

module.exports = { ensureAdmin, ensureCatalogue };
