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

## 3. The API (Render)

1. Create an account at render.com and connect your GitHub account.
2. **New, Blueprint**, choose this repository and the branch to deploy. Render
   reads `render.yaml`.
3. Fill in the values Render asks for:

| Name | Value |
|---|---|
| `MONGODB_URI` | the Atlas connection string |
| `ADMIN_EMAIL` and `ADMIN_PASSWORD` | the first admin's sign-in (8 or more characters) |
| `LIVEKIT_URL`, `LIVEKIT_API_KEY`, `LIVEKIT_API_SECRET` | from LiveKit |

4. Deploy. When it is live, open `https://YOUR-SERVICE.onrender.com/api/health`.
   It should show `{"status":"ok"}`. The admin account is created on the first start.

## 4. The apps

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
