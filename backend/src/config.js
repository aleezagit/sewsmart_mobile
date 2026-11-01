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
  // Off in tests, which sign in many times. A test that checks the limits turns it on.
  rateLimiting: !isTest,
  // How many proxies sit in front of the API (0 for none), so req.ip is the caller's.
  trustProxy: Number(env.TRUST_PROXY) || 0,
  mongoUri: env.MONGODB_URI || 'mongodb://127.0.0.1:27017/sewsmart',
  jwtSecret: env.JWT_SECRET || 'test-secret',
  jwtExpiresIn: env.JWT_EXPIRES_IN || '7d',
  // Render sets RENDER_EXTERNAL_URL to the service's address.
  publicUrl: (env.PUBLIC_URL || env.RENDER_EXTERNAL_URL || `http://localhost:${Number(env.PORT) || 4000}`).replace(/\/$/, ''),
  uploadDir: env.UPLOAD_DIR || 'uploads',
  corsOrigins: (env.CORS_ORIGINS || '').split(',').map((o) => o.trim()).filter(Boolean),
  smtp: {
    host: env.SMTP_HOST,
    port: Number(env.SMTP_PORT) || 587,
    user: env.SMTP_USER,
    pass: env.SMTP_PASS,
    from: env.MAIL_FROM || 'SewSmart <no-reply@sewsmart.app>',
  },
  // Brevo's HTTPS email API. Hosts such as Render's free plan block SMTP, so this is the way to send email there.
  brevoApiKey: env.BREVO_API_KEY,
  // Live video (LiveKit). Without all three, going live is refused with a clear message.
  livekit: {
    url: env.LIVEKIT_URL,
    apiKey: env.LIVEKIT_API_KEY,
    apiSecret: env.LIVEKIT_API_SECRET,
  },
  // Pixabay API key (free) for the photos shown with designs. Without it the apps show icons.
  pixabayApiKey: env.PIXABAY_API_KEY,
  // Google Gemini API key (free, aistudio.google.com/apikey) for the embeddings behind AI
  // recommendations. Without it, recommendations match keywords instead.
  geminiApiKey: env.GEMINI_API_KEY,
  geminiEmbeddingModel: env.GEMINI_EMBEDDING_MODEL || 'gemini-embedding-001',
  tryOnServiceUrl: (env.TRYON_SERVICE_URL || '').replace(/\/$/, ''),
  admin: {
    email: env.ADMIN_EMAIL,
    password: env.ADMIN_PASSWORD,
  },
};
