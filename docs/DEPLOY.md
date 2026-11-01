# Putting the API online

The phone app needs an API it can reach from anywhere. This puts the backend on
Render (free plan) with its database on MongoDB Atlas (free plan), straight
from this repository. Nothing has to be installed on your computer.

## 1. Database (MongoDB Atlas)

1. Create an account at mongodb.com/atlas and a free **M0** cluster.
2. **Database Access**: add a user with a password.
3. **Network Access**: add `0.0.0.0/0` (Render's addresses change).
4. **Connect, Drivers**: copy the connection string, such as
   `mongodb+srv://USER:PASSWORD@cluster0.xxxxx.mongodb.net/sewsmart?retryWrites=true&w=majority`.
   Put your password in place of `PASSWORD` and keep `/sewsmart` in the path.

## 2. Live video (LiveKit)

Create a project at cloud.livekit.io, then **Settings, Keys, Create key**. Note
the project URL (`wss://....livekit.cloud`), the API key and the API secret.

## 3. Email for sign-up codes (Brevo)

A new customer gets a 4-digit code by email, and password resets use email too.
Render's free plan blocks SMTP, so the API sends email through Brevo's web API.

1. Create a free account at brevo.com (300 emails a day).
2. **Senders, Domains & Dedicated IPs, Senders, Add a sender**: use your own
   email address and open the confirmation email Brevo sends to it.
3. **SMTP & API, API Keys, Generate a new API key**. Copy it.
4. On Render set `BREVO_API_KEY` to that key and `MAIL_FROM` to
   `SewSmart <your-verified-email>`. The address must be the verified sender.

Check the spam folder when testing. Without `BREVO_API_KEY` the code is only
written to the server's log.

## 4. AI recommendations (Gemini)

Searches and designs are compared by meaning with Google's free Gemini
embeddings. Without a key, recommendations match keywords instead.

1. Open aistudio.google.com/apikey, sign in with Google and create an API key.
2. Set `GEMINI_API_KEY` on Render. The designs get their embeddings the next
   time the server starts.

## 5. Design photos (Pixabay)

Designs in AI Recommendations show real photos found on Pixabay. Without a key the apps show icons instead.

1. Create a free account at pixabay.com and open pixabay.com/api/docs.
2. The key is shown on that page once you are signed in (100 requests a minute).
3. Set `PIXABAY_API_KEY` on Render. The 24 catalogue designs get their photos
   the next time the server starts.

Pixabay asks apps to credit it (the screens say "Photos by Pixabay") and to
copy photos to their own storage for long-term use. This project keeps their
addresses, which is fine for a demo.

## 6. The API (Render)

1. Create an account at render.com and connect your GitHub account.
2. **New, Blueprint**, choose this repository and the branch to deploy. Render
   reads `render.yaml`.
3. Fill in the values Render asks for:

| Name | Value |
|---|---|
| `MONGODB_URI` | the Atlas connection string |
| `ADMIN_EMAIL` and `ADMIN_PASSWORD` | the first admin's sign-in (8 or more characters) |
| `BREVO_API_KEY`, `MAIL_FROM` | from Brevo (step 3) |
| `GEMINI_API_KEY` | from Google AI Studio (step 4) |
| `PIXABAY_API_KEY` | from Pixabay (step 5) |
| `LIVEKIT_URL`, `LIVEKIT_API_KEY`, `LIVEKIT_API_SECRET` | from LiveKit |

4. Deploy. When it is live, open `https://YOUR-SERVICE.onrender.com/api/health`.
   It should show `{"status":"ok"}`. The admin account is created on the first start.

## 7. The apps

- **Phone app:** open the login screen, tap **Server** and enter
  `https://YOUR-SERVICE.onrender.com`. Or build the APK with that address:
  GitHub, Actions, Build Android APK, Run workflow, and fill in `api_url`.
- **Admin panel:** sign in with `ADMIN_EMAIL` and `ADMIN_PASSWORD`.

## Things to know

- **The free plan sleeps** after 15 minutes without requests, and the first
  request after that takes about a minute. Open the health address a minute
  before a demo.
- **Uploaded photos are lost** when the service restarts or redeploys, because
  the free plan has no permanent disk. For a real launch, add a Render disk
  mounted at `backend/uploads`, or move uploads to object storage.
- **The virtual try-on** needs the Flask service (`tryon-service/`) hosted too,
  with `REPLICATE_API_TOKEN` and `TRYON_SERVICE_URL` pointing to it. Without it,
  try-on answers "not available".
- **Demo data** (`npm run seed`) is for development only. It creates accounts
  with a known password, so do not run it against the online database.
