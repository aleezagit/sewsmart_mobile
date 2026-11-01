const bcrypt = require('bcryptjs');
const config = require('../config');
const Admin = require('../models/Admin');
const Settings = require('../models/Settings');

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

module.exports = { ensureAdmin };
