const { createSchema, mongoose } = require('./base');

const DOCUMENT_TYPES = { tailor: ['cnicFront', 'cnicBack', 'businessProof'], rider: ['cnicFront', 'cnicBack', 'drivingLicence'] };

// A tailor's or rider's request to be verified. The admin decides it.
const verificationSchema = createSchema({
  user_id: { type: String, required: true, index: true },
  role: { type: String, enum: ['tailor', 'rider'], required: true },
  cnic_number: { type: String, default: null },
  documents: [{ _id: false, type: { type: String }, url: String }],
  status: { type: String, enum: ['pending', 'approved', 'rejected'], default: 'pending', index: true },
  submitted_at: { type: Date, default: Date.now },
  rejection_reason: { type: String, default: null },
  admin_message: { type: String, default: null },
  decided_at: { type: Date, default: null },
}, { timestamps: false, hidden: ['user_id', 'role', 'decided_at'] });

const Verification = mongoose.model('Verification', verificationSchema);
Verification.DOCUMENT_TYPES = DOCUMENT_TYPES;
module.exports = Verification;
