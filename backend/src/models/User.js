const { createSchema, mongoose } = require('./base');

const ROLES = ['customer', 'tailor', 'rider'];

const measurementSchema = new mongoose.Schema({
  unit: { type: String, enum: ['cm', 'in'], default: 'cm' },
  height: Number, weight: Number, chest: Number, waist: Number, hips: Number,
  shoulder: Number, arm_length: Number, inseam: Number, neck: Number, wrist: Number,
  updated_at: Date,
}, { _id: false });

const tailorSchema = new mongoose.Schema({
  business_name: String,
  category: { type: String, default: 'Eastern' },
  bio: { type: String, default: '' },
  specialties: { type: [String], default: [] },
  experience_years: { type: Number, default: 0 },
  rating: { type: Number, default: 0 },
  review_count: { type: Number, default: 0 },
}, { _id: false });

const riderSchema = new mongoose.Schema({
  tailor_id: { type: String, default: null },
  is_available: { type: Boolean, default: true },
  cnic_number: String,
  rating: { type: Number, default: 0 },
}, { _id: false });

// One collection for customers, tailors and riders, so a user keeps one ID
// across the app (T001 is both the user and the tailor profile).
const userSchema = createSchema({
  name: { type: String, required: true },
  // Riders added by a tailor may have no email and sign in with their phone.
  email: { type: String, lowercase: true, trim: true },
  phone: { type: String, required: true },
  password_hash: String,
  role: { type: String, enum: ROLES, required: true },
  is_verified: { type: Boolean, default: false },
  avatar: { type: String, default: null },
  city: { type: String, default: null },
  status: { type: String, enum: ['active', 'suspended'], default: 'active' },
  deleted_at: { type: Date, default: null },
  // Raised by logout and password changes, which ends every older token.
  token_version: { type: Number, default: 0 },
  tailor: tailorSchema,
  rider: riderSchema,
  measurements: measurementSchema,
  wishlist: { type: [String], default: [] },
}, { hidden: ['password_hash', 'token_version', 'tailor', 'rider', 'measurements', 'wishlist', 'deleted_at', 'status'] });

userSchema.index({ email: 1 }, { unique: true, partialFilterExpression: { email: { $type: 'string' } } });
userSchema.index({ phone: 1 }, { unique: true });
userSchema.index({ role: 1, 'rider.tailor_id': 1 });

userSchema.virtual('isActive').get(function isActive() {
  return this.status === 'active' && !this.deleted_at;
});

// The tailor's public name. A tailor signs up with a business name.
userSchema.virtual('displayName').get(function displayName() {
  return (this.role === 'tailor' && this.tailor?.business_name) || this.name;
});

const User = mongoose.model('User', userSchema);
User.ROLES = ROLES;
module.exports = User;
