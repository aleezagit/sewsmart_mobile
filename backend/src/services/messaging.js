const nodemailer = require('nodemailer');
const config = require('../config');
const { HttpError } = require('../utils/errors');

// Email goes out through Brevo's HTTPS API when BREVO_API_KEY is set, else
// through SMTP when it is configured. With neither, the message is written to
// the server log so the code can still be used during development.

const transport = config.smtp.host
  ? nodemailer.createTransport({
    host: config.smtp.host,
    port: config.smtp.port,
    secure: config.smtp.port === 465,
    auth: config.smtp.user ? { user: config.smtp.user, pass: config.smtp.pass } : undefined,
  })
  : null;

// "SewSmart <me@example.com>" becomes { name, email }.
function sender() {
  const match = /^\s*(.*?)\s*<([^>]+)>\s*$/.exec(config.smtp.from);
  return match ? { name: match[1] || undefined, email: match[2] } : { email: config.smtp.from.trim() };
}

function logMessage(to, text) {
  if (!config.isTest) console.log(`[email to ${to}] ${text}`);
}

async function sendEmail(to, subject, text) {
  if (config.brevoApiKey) {
    const response = await fetch('https://api.brevo.com/v3/smtp/email', {
      method: 'POST',
      headers: { 'api-key': config.brevoApiKey, 'content-type': 'application/json', accept: 'application/json' },
      body: JSON.stringify({ sender: sender(), to: [{ email: to }], subject, textContent: text }),
    });
    if (!response.ok) {
      console.error(`Brevo refused the email (${response.status}): ${await response.text()}`);
      throw new HttpError(502, 'We could not send the email. Please try again in a moment.');
    }
    return;
  }
  if (!transport) return logMessage(to, `${subject}: ${text}`);
  await transport.sendMail({ from: config.smtp.from, to, subject, text });
}

module.exports = { sendEmail };
