const { createSchema, mongoose } = require('./base');

// Types are listed in docs/API.md, section 2. The screens pick an icon by type.
const notificationSchema = createSchema({
  user_id: { type: String, required: true, index: true },
  title: { type: String, required: true },
  body: { type: String, default: '' },
  type: { type: String, required: true },
  is_read: { type: Boolean, default: false },
}, { stringId: false, hidden: ['user_id'] });

module.exports = mongoose.model('Notification', notificationSchema);
