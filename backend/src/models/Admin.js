const { createSchema, mongoose } = require('./base');

const adminSchema = createSchema({
  name: { type: String, required: true },
  email: { type: String, required: true, unique: true, lowercase: true, trim: true },
  password_hash: { type: String, required: true },
  token_version: { type: Number, default: 0 },
}, { hidden: ['password_hash', 'token_version', 'created_at'] });

module.exports = mongoose.model('Admin', adminSchema);
