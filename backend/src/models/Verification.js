const { createSchema, mongoose } = require('./base');

const DOCUMENT_TYPES = ['cnicFront', 'cnicBack', 'businessProof'];

// A tailor's request to be verified. The admin decides it.
const verificationSchema = createSchema({
  user_id: { type: String, required: true, index: true },
  cnic_number: { type: String, default: null },
  documents: [{ _id: false, type: { type: String }, url: String }],
  status: { type: String, enum: ['pending', 'approved', 'rejected'], default: 'pending', index: true },
  submitted_at: { type: Date, default: Date.now },
  rejection_reason: { type: String, default: null },
  admin_message: { type: String, default: null },
  decided_at: { type: Date, default: null },
}, { timestamps: false, hidden: ['user_id', 'decided_at'] });

const Verification = mongoose.model('Verification', verificationSchema);
Verification.DOCUMENT_TYPES = DOCUMENT_TYPES;
module.exports = Verification;
