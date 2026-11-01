const crypto = require('crypto');

// The link to JazzCash, EasyPaisa, bank and card payments, used when a customer
// adds money to their wallet. Each provider needs merchant credentials that the
// project does not have yet, so this sandbox approves every charge without
// touching a real account, and returns a transaction ID in the provider's
// format. Replace `charge` with the provider calls once merchant accounts
// exist; the routes only rely on the returned status and reason.
async function charge({ method, amount }) {
  if (!(amount > 0)) return { status: 'failed', reason: 'The amount must be more than zero' };
  const prefix = { jazzCash: 'JC', easyPaisa: 'EP', bank: 'BT', card: 'CD' }[method];
  return { status: 'completed', transaction_id: `${prefix}-${crypto.randomBytes(5).toString('hex').toUpperCase()}` };
}

module.exports = { charge };
