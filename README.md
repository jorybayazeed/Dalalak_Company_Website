# Dalalak Company Website (Flutter + Backend)

This project is now wired to a real backend API (not hardcoded UI data only).

## What is functional now

- Real login against backend users
- Dashboard metrics loaded from backend
- Tours loaded from backend
- Create tour and persist it
- Delete tour and persist changes
- Bookings loaded from backend
- Confirm/Cancel booking status updates and persist changes

## Project structure

- `lib/` Flutter frontend
- `backend/` Node.js + Express API
- `backend/data/db.json` JSON database (seed + persisted updates)

## 1) Run backend

```bash
cd backend
npm install
npm run start
```

Backend runs on:

- `http://localhost:4000`

Important:

- Business data endpoints are Firebase-only (no local fake fallback).
- If `FIREBASE_CREDENTIALS_PATH` is missing, tours/bookings/guides/customers/reviews/reports/rewards endpoints return `503`.

Set Firebase credentials before start:

```bash
export FIREBASE_CREDENTIALS_PATH=/absolute/path/to/service-account.json
```

Health check:

- `GET http://localhost:4000/api/health`

## 2) Run Flutter app

In another terminal from project root:

```bash
flutter pub get
flutter run -d chrome
```

The Flutter app defaults to backend URL:

- `http://localhost:4000`

If you need a different backend URL, run with:

```bash
flutter run -d chrome --dart-define=DALALAK_API_URL=http://YOUR_HOST:4000
```

## Test accounts

Use one of these accounts from `backend/data/db.json`:

- Company: `company@example.com` / `12345678`
- Admin: `admin@example.com` / `12345678`
- Staff: `staff@example.com` / `12345678`

Select the matching role in the login form.

## Main API endpoints

- `POST /api/auth/login`
- `POST /api/auth/logout`
- `GET /api/dashboard/overview`
- `GET /api/tours`
- `POST /api/tours`
- `PUT /api/tours/:id`
- `DELETE /api/tours/:id`
- `GET /api/bookings`
- `PATCH /api/bookings/:id/status`
- `GET /api/guides`
- `GET /api/customers`
- `GET /api/reviews`
- `GET /api/notifications`
- `GET /api/reports/summary`
- `POST /api/integration/push/tours` (push local company tours to Firebase `tourPackages`)

## Mobile app sync (Dalalak_APP)

To make tours created from the company website appear in the tourist Explore page in `Dalalak_APP`, both systems must use the same Firebase project.

1. Configure backend Firebase credentials:

```bash
export FIREBASE_CREDENTIALS_PATH=/absolute/path/to/service-account.json
cd backend
npm run start
```

2. Verify integration health:

- `GET /api/health`
- `integration.firebaseInitialized` must be `true`

3. Tours created from company web are written directly to Firebase `tourPackages`.

Optional bulk push endpoint (explicit payload only):

```bash
curl -X POST http://localhost:4000/api/integration/push/tours \
	-H "Authorization: Bearer <COMPANY_TOKEN>" \
	-H "Content-Type: application/json" \
	-d '{"tours": [{"id":"t1","name":"Sample","city":"Riyadh","price":500,"date":"2026-06-15","guide":"Guide","capacity":20,"duration":"3 Hours"}]}'
```

After create/push, tours are written to Firebase `tourPackages` with `status: Published`, so they are visible in the mobile app Explore flow and can be booked.

## Run Company + App On Different Servers

1. Company web + backend (this repo):

```bash
cd /workspaces/Dalalak_Company_Website/backend
export FIREBASE_CREDENTIALS_PATH=/absolute/path/to/service-account.json
npm run start
```

2. Tourist/Guide app (separate repo pulled locally):

```bash
cd /workspaces/Dalalak_APP
flutter pub get
flutter run
```

Use the same Firebase project in both repos so data is shared in real-time.

## Notes

- This backend uses file-based persistence (`db.json`) for fast local development.
- For production, switch to PostgreSQL/MySQL and secure auth (hashed passwords + JWT expiry + refresh strategy).
