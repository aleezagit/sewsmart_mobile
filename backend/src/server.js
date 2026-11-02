const config = require('./config');
const db = require('./db');
const { createApp } = require('./app');
const { startJobs } = require('./services/jobs');
const { ensureAdmin, ensureCatalogue, enrichCatalogue } = require('./services/bootstrap');

async function main() {
  await db.connect();
  await ensureAdmin();
  await ensureCatalogue();
  const app = createApp();
  app.listen(config.port, () => console.log(`SewSmart API listening on ${config.publicUrl}`));
  startJobs();
  // Pictures and embeddings can take minutes, so the server does not wait for them.
  enrichCatalogue();
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
