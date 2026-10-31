const nodemailer = require('nodemailer');
const config = require('../config');

// Email goes through SMTP when it is configured. Without SMTP, and for SMS
// until an SMS provider is chosen, the message is written to the server log so
// the code can still be used during development.

const transport = config.smtp.host
  ? nodemailer.createTransport({
    host: config.smtp.host,
    port: config.smtp.port,
    secure: config.smtp.port === 465,
    auth: config.smtp.user ? { user: config.smtp.user, pass: config.smtp.pass } : undefined,
  })
  : null;

function logMessage(channel, to, text) {
  if (!config.isTest) console.log(`[${channel} to ${to}] ${text}`);
}

async function sendEmail(to, subject, text) {
  if (!transport) return logMessage('email', to, `${subject}: ${text}`);
  await transport.sendMail({ from: config.smtp.from, to, subject, text });
}

async function sendSms(phone, text) {
  logMessage('sms', phone, text);
}

module.exports = { sendEmail, sendSms };
