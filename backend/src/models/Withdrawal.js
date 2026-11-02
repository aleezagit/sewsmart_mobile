const { createSchema, mongoose } = require('./base');

const withdrawalSchema = createSchema({
  user_id: { type: String, required: true, index: true },
  account_id: { type: String, required: true },
  amount: { type: Number, required: true },
  status: { type: String, enum: ['pending', 'paid', 'failed'], default: 'pending' },
  requested_at: { type: Date, default: Date.now },
  paid_at: { type: Date, default: null },
}, { timestamps: false, hidden: ['user_id', 'account_id'] });

module.exports = mongoose.model('Withdrawal', withdrawalSchema);
