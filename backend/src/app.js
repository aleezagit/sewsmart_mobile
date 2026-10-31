const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const config = require('./config');
const { requireUser, requireRole } = require('./middleware/auth');
const { uploadRoot } = require('./middleware/upload');
const { notFoundHandler, errorHandler } = require('./middleware/errors');

function createApp() {
  const app = express();
  app.disable('x-powered-by');
  app.use(helmet({ crossOriginResourcePolicy: { policy: 'cross-origin' } }));
  app.use(cors(config.corsOrigins.length ? { origin: config.corsOrigins } : undefined));
  app.use(express.json({ limit: '1mb' }));
  if (!config.isTest) app.use(morgan(config.isProduction ? 'combined' : 'dev'));

  app.use('/uploads', express.static(uploadRoot, { maxAge: '7d' }));
  app.get('/api/health', (req, res) => res.json({ status: 'ok' }));

  // Open routes, and the admin panel, which checks its own token.
  app.use('/api/auth', require('./routes/auth'));
  app.use('/api/admin', require('./routes/admin'));

  // Everything below needs a signed-in customer, tailor or rider.
  app.use('/api', requireUser);
  app.use('/api/users', require('./routes/users'));
  app.use('/api/tailors', require('./routes/tailors'));
  app.use('/api/orders', require('./routes/orders'));
  app.use('/api/payments', requireRole('customer'), require('./routes/payments'));
  app.use('/api/reviews', requireRole('customer'), require('./routes/reviews'));
  app.use('/api/riders', require('./routes/riders'));
  app.use('/api/deliveries', requireRole('rider'), require('./routes/deliveries'));
  app.use('/api/notifications', require('./routes/notifications'));
  app.use('/api/streams', require('./routes/streams'));
  app.use('/api/verifications', require('./routes/verifications'));
  app.use('/api', require('./routes/customer'));
  app.use('/api', require('./routes/ai'));
  app.use('/api', require('./routes/chat'));
  app.use('/api', require('./routes/payouts'));
  app.use('/api', require('./routes/support'));

  app.use(notFoundHandler);
  app.use(errorHandler);
  return app;
}

module.exports = { createApp };
