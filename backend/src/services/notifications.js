const Notification = require('../models/Notification');

// Adds a notification to a user's list. `type` decides the icon in the app
// (docs/API.md, section 2).
async function notify(userId, type, title, body = '') {
  if (!userId) return;
  await Notification.create({ user_id: userId, type, title, body });
}

module.exports = { notify };
