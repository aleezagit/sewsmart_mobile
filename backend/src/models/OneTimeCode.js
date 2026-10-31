const { createSchema, mongoose } = require('./base');

// Short-lived codes: phone OTPs at sign-up and password reset codes.
// `target` is the phone number or the user ID. Only a hash of the code is kept.
const oneTimeCodeSchema = createSchema({
  purpose: { type: String, enum: ['phone', 'reset'], required: true },
  target: { type: String, required: true },
  code_hash: { type: String, required: true },
  expires_at: { type: Date, required: true },
  attempts: { type: Number, default: 0 },
  verified_at: { type: Date, default: null },
}, { stringId: false });

oneTimeCodeSchema.index({ purpose: 1, target: 1 });
oneTimeCodeSchema.index({ code_hash: 1 });
// MongoDB removes a code a day after it expires.
oneTimeCodeSchema.index({ expires_at: 1 }, { expireAfterSeconds: 86400 });

module.exports = mongoose.model('OneTimeCode', oneTimeCodeSchema);
