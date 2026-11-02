const mongoose = require('mongoose');
const config = require('./config');

async function connect(uri = config.mongoUri) {
  mongoose.set('strictQuery', true);
  await mongoose.connect(uri);
  await mongoose.connection.syncIndexes();
  return mongoose.connection;
}

module.exports = { connect, disconnect: () => mongoose.disconnect() };
