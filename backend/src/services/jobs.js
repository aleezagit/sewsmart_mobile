const Order = require('../models/Order');
const Dispute = require('../models/Dispute');
const Withdrawal = require('../models/Withdrawal');
const { setStatus } = require('./orderAccess');
const { notify } = require('./notifications');
const { startOfDay } = require('../utils/dates');

// After delivery the customer has this long to raise a problem. Then the
// order completes and the tailor's share becomes available to withdraw.
const DISPUTE_WINDOW_DAYS = 3;

async function completeDeliveredOrders(now = new Date()) {
  const cutoff = new Date(now.getTime() - DISPUTE_WINDOW_DAYS * 24 * 60 * 60 * 1000);
  const orders = await Order.find({ status: 'delivered', delivered_at: { $lte: cutoff } });
  for (const order of orders) {
    if (await Dispute.exists({ order_id: order.id, status: 'open' })) continue;
    setStatus(order, 'completed');
    order.completed_at = now;
    await order.save();
    await notify(order.tailor_id, 'order', 'Payment Released', `${order.id} is complete. Your earnings are ready to withdraw.`);
  }
}

// Payouts are processed every Monday: requests from before that day are paid.
async function payWithdrawals(now = new Date()) {
  if (now.getDay() !== 1) return;
  const pending = await Withdrawal.find({ status: 'pending', requested_at: { $lt: startOfDay(now) } });
  for (const withdrawal of pending) {
    withdrawal.status = 'paid';
    withdrawal.paid_at = now;
    await withdrawal.save();
    await notify(withdrawal.user_id, 'payment', 'Payout Sent', `Rs ${withdrawal.amount.toLocaleString('en-PK')} has been sent to your account.`);
  }
}

async function runJobs(now = new Date()) {
  await completeDeliveredOrders(now);
  await payWithdrawals(now);
}

// Runs the jobs now and then every hour.
function startJobs() {
  const run = () => runJobs().catch((err) => console.error('Scheduled job failed:', err));
  run();
  return setInterval(run, 60 * 60 * 1000);
}

module.exports = { runJobs, startJobs, completeDeliveredOrders, payWithdrawals };
