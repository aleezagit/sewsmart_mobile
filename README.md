# SewSmart

SewSmart is an AI-powered tailoring marketplace that connects customers and tailors. Customers browse tailors, place and track orders, get AI design recommendations and preview garments with a virtual try-on. It is a university Final Year Project.

## Repository layout

| Path | What it is |
| --- | --- |
| `lib/` | Flutter mobile app for customers and tailors |
| `sewsmart_admin/` | Flutter web admin panel |
| `backend/` | Node.js + Express + MongoDB REST API |
| `tryon-service/` | Flask service for the virtual try-on |
| `docs/API.md` | API contract between the apps and the backend |

## Run everything

You need Node.js 20 or newer, MongoDB, and Flutter.

**1. The backend**

```bash
cd backend
cp .env.example .env        # then set JWT_SECRET and ADMIN_PASSWORD
npm install
npm run seed                # creates the admin and demo data (add -- --reset to start over)
npm start                   # http://localhost:4000
```

The demo customers and tailors sign in with the password `sewsmart123`, for example `ayesha@email.com` (customer) and `sana@couture.com` (tailor). The admin signs in with `ADMIN_EMAIL` and `ADMIN_PASSWORD` from `.env`. Reset codes and OTP codes are printed in the server log until SMTP and an SMS provider are set up.

**2. The mobile app**

```bash
flutter pub get
flutter run                                              # Android emulator reaches the backend at http://10.0.2.2:4000
flutter run --dart-define=API_URL=http://192.168.1.5:4000   # a real phone, using your computer's address
```

**3. The admin panel**

```bash
cd sewsmart_admin
flutter pub get
flutter run -d chrome                                    # uses http://localhost:4000
flutter run -d chrome --dart-define=API_URL=https://api.example.com
```

**4. The virtual try-on (optional)** – see `tryon-service/`. Without it, the try-on screen reports that the service is not available.

## Tests

```bash
cd backend && npm test      # needs MongoDB; set MONGODB_TEST_URI to use another database
cd tryon-service && pip install -r requirements.txt && python -m unittest
```

## Working on this project

All work goes through issues, short-lived branches and pull requests into `develop`. Read [CONTRIBUTING.md](CONTRIBUTING.md) before your first commit.

| Branch | Purpose |
| --- | --- |
| `main` | Stable, demo-ready |
| `develop` | Integration branch and repository default |
| `feature/*` | One branch per issue |
