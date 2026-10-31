require('dotenv').config();

const env = process.env;
const isTest = env.NODE_ENV === 'test';

if (!env.JWT_SECRET && !isTest) {
  throw new Error('JWT_SECRET is not set. Copy .env.example to .env and fill it in.');
}

module.exports = {
  port: Number(env.PORT) || 4000,
  isProduction: env.NODE_ENV === 'production',
  isTest,
  mongoUri: env.MONGODB_URI || 'mongodb://127.0.0.1:27017/sewsmart',
  jwtSecret: env.JWT_SECRET || 'test-secret',
  jwtExpiresIn: env.JWT_EXPIRES_IN || '7d',
  publicUrl: (env.PUBLIC_URL || `http://localhost:${Number(env.PORT) || 4000}`).replace(/\/$/, ''),
  uploadDir: env.UPLOAD_DIR || 'uploads',
  corsOrigins: (env.CORS_ORIGINS || '').split(',').map((o) => o.trim()).filter(Boolean),
  smtp: {
    host: env.SMTP_HOST,
    port: Number(env.SMTP_PORT) || 587,
    user: env.SMTP_USER,
    pass: env.SMTP_PASS,
    from: env.MAIL_FROM || 'SewSmart <no-reply@sewsmart.app>',
  },
  tryOnServiceUrl: (env.TRYON_SERVICE_URL || '').replace(/\/$/, ''),
  admin: {
    email: env.ADMIN_EMAIL || 'admin@sewsmart.com',
    password: env.ADMIN_PASSWORD,
  },
};
