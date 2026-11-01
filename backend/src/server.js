const config = require('./config');
const db = require('./db');
const { createApp } = require('./app');
const { startJobs } = require('./services/jobs');
const { ensureAdmin } = require('./services/bootstrap');

async function main() {
  await db.connect();
  await ensureAdmin();
  const app = createApp();
  app.listen(config.port, () => console.log(`SewSmart API listening on ${config.publicUrl}`));
  startJobs();
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
