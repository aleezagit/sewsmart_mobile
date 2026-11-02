const { mongoose } = require('./base');

// The platform settings the admin manages (docs/API.md, 4.11). One document.
const settingsSchema = new mongoose.Schema({
  _id: { type: String, default: 'platform' },
  commission_rate: { type: Number, default: 8.5 },
  categories: { type: [String], default: ['Bridal', 'Eastern', 'Western', 'Casual', 'Children'] },
  notify_new_order: { type: Boolean, default: true },
  notify_order_complete: { type: Boolean, default: true },
  notify_new_verification: { type: Boolean, default: true },
  notify_dispute: { type: Boolean, default: true },
  notify_payment: { type: Boolean, default: false },
  notify_marketing: { type: Boolean, default: false },
  two_fa_enabled: { type: Boolean, default: false },
  session_timeout: { type: Number, enum: [15, 30, 60, 120], default: 30 },
}, {
  versionKey: false,
  toJSON: {
    transform(doc, ret) {
      delete ret._id;
      return ret;
    },
  },
});

settingsSchema.statics.current = async function current() {
  return (await this.findById('platform')) || this.create({ _id: 'platform' });
};

module.exports = mongoose.model('Settings', settingsSchema);
