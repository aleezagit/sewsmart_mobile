const { createSchema, mongoose } = require('./base');

const disputeSchema = createSchema({
  order_id: { type: String, required: true, index: true },
  raised_by: { type: String, required: true },
  reason: { type: String, required: true },
  details: { type: String, required: true },
  status: { type: String, enum: ['open', 'resolved'], default: 'open', index: true },
  resolution: { type: String, enum: ['refund', 'warning', 'dismiss', null], default: null },
  resolution_notes: { type: String, default: null },
}, { hidden: ['raised_by'] });

module.exports = mongoose.model('Dispute', disputeSchema);
