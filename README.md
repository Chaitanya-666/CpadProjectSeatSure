# SeatSure

Book library seats by time slot, with QR check-in and automatic release of
no-show bookings.

CPAD (R5CO4004L) ESE mini project, Chaitanya Shinde (231070066), B.Tech CE, VJTI.

![CI](https://github.com/Chaitanya-666/CpadProjectSeatSure/actions/workflows/ci.yml/badge.svg)

**Live:** https://seatsure-9hn0.onrender.com (web app) · [`/api/health`](https://seatsure-9hn0.onrender.com/api/health). Free tier: the first request after 15 idle minutes takes up to a minute. Before a demo run `scripts/wake.sh`: it waits until the API and the database both answer.

## Screenshots and demo

**Real phone, live server (10 Nov 2026).** Release APK 1.0.1 on an Android
phone against the deployed API. Seats were checked in with the phone camera
scanning the seat QR codes.

<p align="center">
  <img src="docs/evidence/2026-11-10-phone/qr-checkin.gif" width="280" alt="Booking seat A1, scanning the wrong seat's QR, then checking in at A1 (3x speed)">
</p>
<p align="center"><sub>Book A1, scan the wrong seat (refused), scan A1 (checked in). 3x speed.
Full run: <a href="docs/evidence/2026-11-10-phone/seatsure-phone-run.mp4">seatsure-phone-run.mp4</a> (4 min 37 s).</sub></p>

| Rooms, free now | Seat map | Double booking refused | Booking rules |
|---|---|---|---|
| <img src="docs/evidence/2026-11-10-phone/screens/Screenshot_20261110_221139.jpg" width="200"> | <img src="docs/evidence/2026-11-10-phone/screens/Screenshot_20261110_221404.jpg" width="200"> | <img src="docs/evidence/2026-11-10-phone/screens/Screenshot_20261110_221408.jpg" width="200"> | <img src="docs/evidence/2026-11-10-phone/screens/Screenshot_20261110_221148.jpg" width="200"> |

| Wrong seat's QR | Not a SeatSure QR | Checked in by camera | Scanned again |
|---|---|---|---|
| <img src="docs/evidence/2026-11-10-phone/screens/Screenshot_20261110_221310.jpg" width="200"> | <img src="docs/evidence/2026-11-10-phone/screens/Screenshot_20261110_221320.jpg" width="200"> | <img src="docs/evidence/2026-11-10-phone/screens/Screenshot_20261110_221346.jpg" width="200"> | <img src="docs/evidence/2026-11-10-phone/screens/Screenshot_20261110_221457.jpg" width="200"> |

| Booking checked in | Left early: completed | Room closed for the day | Check-in tab |
|---|---|---|---|
| <img src="docs/evidence/2026-11-10-phone/screens/Screenshot_20261110_221353.jpg" width="200"> | <img src="docs/evidence/2026-11-10-phone/screens/Screenshot_20261110_221507.jpg" width="200"> | <img src="docs/evidence/2026-11-10-phone/screens/Screenshot_20261110_221420.jpg" width="200"> | <img src="docs/evidence/2026-11-10-phone/screens/Screenshot_20261110_221335.jpg" width="200"> |

All 31 screenshots of the run: [`docs/evidence/2026-11-10-phone/screens/`](docs/evidence/2026-11-10-phone/screens/).

### Librarian and student together (10 Nov 2026)

The librarian on the **Linux desktop build**, a student on the **Android phone**,
and a second student (Riya) booking through the API, all on the live server.
Videos (no audio): [laptop, 7 min 43 s](docs/evidence/2026-11-10-admin/laptop-admin-run.mp4) ·
[phone, 6 min 9 s](docs/evidence/2026-11-10-admin/phone-run.mp4).

| Librarian: today's bookings with names | Librarian: dashboard live (1 in use, 1 waiting) |
|---|---|
| <img src="docs/evidence/2026-11-10-admin/laptop/01-bookings-today.jpg" width="420"> | <img src="docs/evidence/2026-11-10-admin/laptop/02-dashboard-live.jpg" width="420"> |
| **Librarian: Silent Study Zone switched off** | **Librarian: QR sheet after a new code for A4** |
| <img src="docs/evidence/2026-11-10-admin/laptop/03-room-switched-off.jpg" width="420"> | <img src="docs/evidence/2026-11-10-admin/laptop/05-qr-sheet-new-a4.jpg" width="420"> |

| Riya's seat A3 shows as taken | Booking cancelled | Checked in at A6 | Room off: gone for students |
|---|---|---|---|
| <img src="docs/evidence/2026-11-10-admin/screens/Screenshot_20261110_225337.jpg" width="200"> | <img src="docs/evidence/2026-11-10-admin/screens/Screenshot_20261110_225357.jpg" width="200"> | <img src="docs/evidence/2026-11-10-admin/screens/Screenshot_20261110_225427.jpg" width="200"> | <img src="docs/evidence/2026-11-10-admin/screens/Screenshot_20261110_225637.jpg" width="200"> |

| Room on again, details kept | Old A4 code after a new one | Too early to check in | History |
|---|---|---|---|
| <img src="docs/evidence/2026-11-10-admin/screens/Screenshot_20261110_225647.jpg" width="200"> | <img src="docs/evidence/2026-11-10-admin/screens/Screenshot_20261110_225744.jpg" width="200"> | <img src="docs/evidence/2026-11-10-admin/screens/Screenshot_20261110_225914.jpg" width="200"> | <img src="docs/evidence/2026-11-10-admin/screens/Screenshot_20261110_225834.jpg" width="200"> |

Riya never checked in, so at 23:00 (start + 15 min) her booking turned into
**No-show** by itself and the seat was free again, with no timer running.
All 18 phone screenshots: [`docs/evidence/2026-11-10-admin/screens/`](docs/evidence/2026-11-10-admin/screens/).

More screens (Android, web, dark theme) are in [`docs/report/images/`](docs/report/images/)
and in the project report.

## What it does

**Students**
- See every reading room with how many seats are free right now.
- Pick a day, start time and length; the seat map shows each seat as free,
  taken or yours, and refreshes every 15 s.
- Book a seat. The database guarantees nobody else holds it for that time.
- At the seat, scan the QR code on the desk to check in (or type the code
  printed under it).
- Miss the check-in window (15 min after the start) and the seat is released
  automatically for others.
- Leave early to free the seat, cancel a booking, see history.

**Librarian (admin)**
- Dashboard: seats in use now, waiting check-in, free; per-room bookings,
  attendance, no-show rate, seat-hours used; busiest hours.
- Every booking of a day with the student's name.
- Add rooms and seats, open/close a room, disable a seat.
- Printable QR sheet per room; issue a new QR for a seat (the old one stops working).

## Stack

| Layer | Tech | Why |
|---|---|---|
| App | Flutter 3 (Dart), Provider | One codebase for Android, web and Linux desktop |
| API | Node.js 24+, Express 5, zod, JWT | Small REST API; every rule is code we can show |
| Database | PostgreSQL 18 | Range types + exclusion constraints stop double booking inside the DB |
| Hosting | Render (Docker) + Neon (Postgres) | Free tiers, one public URL for API and web app |
| CI | GitHub Actions | API tests on real Postgres, Flutter tests, Docker image check |

```mermaid
flowchart LR
  A[Flutter app<br/>Android / Web / Linux] -- HTTPS + JSON<br/>Bearer JWT --> B[Express API<br/>Node.js]
  B -- SQL over TLS --> C[(PostgreSQL)]
  B -. serves .-> W[Flutter web build]
```

## Where is X (code map)

| Thing | File |
|---|---|
| Tables, constraints (no double booking) | `api/migrations/001_init.sql` |
| Booking a seat (transaction, row lock, limit) | `api/src/routes/bookings.js` |
| QR check-in and its error reasons | `api/src/routes/checkin.js` |
| No-show release (lazy expiry) | `api/src/middleware/noShowSweep.js` |
| Time rules (15-min grid, 30 min–4 h, 7 days, opening hours) | `api/src/lib/slots.js` |
| Login, sign-up, password hashing | `api/src/routes/auth.js`, `api/src/lib/password.js` |
| Admin rooms/seats/stats | `api/src/routes/admin.js` |
| DB error → friendly 409 message | `api/src/middleware/errorHandler.js` |
| Demo data | `api/scripts/seed.js` |
| API tests | `api/test/*.test.js` |
| App start, theme, login gate | `app/lib/main.dart` |
| HTTP client, error handling | `app/lib/api/api_client.dart` |
| Login state, server address | `app/lib/state/session.dart` |
| My bookings state (book, cancel, check in) | `app/lib/state/bookings_model.dart` |
| Seat map + booking | `app/lib/screens/room_screen.dart` |
| QR scanner | `app/lib/screens/scan_screen.dart` |
| Admin screens | `app/lib/screens/admin/` |
| App tests | `app/test/` |
| Deployment | `Dockerfile`, `render.yaml` |

## Run it locally

Needs Node 22+, PostgreSQL, Flutter.

```sh
# 1. database (once)
psql -h 127.0.0.1 -U postgres -c "CREATE ROLE seatsure LOGIN PASSWORD 'seatsure_local'"
psql -h 127.0.0.1 -U postgres -c "CREATE DATABASE seatsure_dev OWNER seatsure"
psql -h 127.0.0.1 -U postgres -c "CREATE DATABASE seatsure_test OWNER seatsure"

# 2. API
cd api
cp .env.example .env
npm install
npm run seed        # migrate + demo data (npm run seed -- --bookings keeps seats/QRs)
npm run dev         # http://localhost:3000/api/health

# 3. app (another terminal)
cd app
flutter run -d linux                    # desktop, talks to localhost:3000
flutter run -d emulator-5554            # Android emulator, talks to 10.0.2.2:3000
flutter build web && WEB_DIR=../app/build/web npm --prefix ../api run dev   # web, same origin
```

Release APK pointing at the deployed API:

```sh
flutter build apk --release --split-per-abi --dart-define=API_BASE_URL=https://<your-app>.onrender.com
```

The app's **Server** screen (login page, top right) switches to another
address at runtime, e.g. a laptop on the same hotspot: `http://<laptop-ip>:3000`.

### Demo logins (after `npm run seed` on a local database)

| Role | Email | Password |
|---|---|---|
| Admin | admin@seatsure.app | Admin@1234 |
| Student | chaitanya@seatsure.app | Student@123 |
| Student | riya@seatsure.app | Student@123 |

The repo is public, so these passwords are public. Seeding a hosted
database refuses to run unless `SEED_ADMIN_PASSWORD` and
`SEED_STUDENT_PASSWORD` (12+ characters) are set in a git-ignored env file;
the live deployment uses those private passwords instead.

## Tests

```sh
cd api && npm test        # 28 tests against the seatsure_test database
cd app && flutter test    # model + widget tests
```

The API tests include two parallel bookings of one seat (exactly one must
win) and parallel bookings by one student past the limit; both were checked
to fail when the protection is removed.

## API

All under `/api`. Send `Authorization: Bearer <token>` except for health,
config, register and login. Errors look like
`{"error": {"code": "seat_taken", "message": "..."}}`.

| Method | Path | Who | What |
|---|---|---|---|
| GET | `/health` | anyone | server + DB status |
| GET | `/config` | anyone | booking rules (grid, limits, check-in window) |
| POST | `/auth/register` | anyone | create a student account → token |
| POST | `/auth/login` | anyone | → token |
| GET | `/auth/me` | user | current user |
| GET | `/rooms` | user | open rooms + free-now counts |
| GET | `/rooms/:id/availability?start&end` | user | each seat free / taken / mine |
| GET | `/rooms/:id/timeline?date` | user | busy intervals per seat for a day |
| POST | `/bookings` | user | `{seatId, start, end}` → booking |
| GET | `/bookings/me?scope=upcoming\|history` | user | my bookings |
| POST | `/bookings/:id/cancel` | owner | cancel before check-in |
| POST | `/bookings/:id/checkout` | owner | leave early |
| POST | `/checkin` | user | `{qrToken}` → checked-in booking |
| GET/POST/PATCH | `/admin/rooms…`, `/admin/seats…` | admin | manage rooms, seats, QR codes |
| GET | `/admin/bookings?date` | admin | a day's bookings with names |
| GET | `/admin/stats?days` | admin | dashboard numbers |

## Deploy (Render + Neon)

1. Neon: create a project, copy the connection string.
2. Render: New → Blueprint → this repo. Paste the Neon string as
   `DATABASE_URL`. Render builds the `Dockerfile`, which builds the web app
   and runs migrations on start.
3. Open `https://<app>.onrender.com/api/health`. Seed once from a laptop,
   with the Neon URL and private `SEED_*_PASSWORD` values in the git-ignored
   `api/.env.neon`: `cd api && node --env-file=.env.neon scripts/seed.js`.
   (If your shell sets `PGPORT`/`PGHOST`, unset them: the driver uses them
   when the URL has no port.)

Free Render services sleep after 15 minutes idle (first request then takes
up to a minute). Open `/api/health` a couple of minutes before a demo.
