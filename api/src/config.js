// All settings come from environment variables, with defaults that suit local
// development. On Render they are set in the dashboard (see render.yaml).

function int(name, fallback) {
  const raw = process.env[name];
  if (raw === undefined || raw === '') return fallback;
  const n = Number.parseInt(raw, 10);
  if (Number.isNaN(n)) throw new Error(`${name} must be an integer, got "${raw}"`);
  return n;
}

const nodeEnv = process.env.NODE_ENV ?? 'development';

export const config = {
  nodeEnv,
  port: int('PORT', 3000),
  databaseUrl:
    process.env.DATABASE_URL ?? 'postgres://seatsure:seatsure_local@127.0.0.1:5432/seatsure_dev',
  // Hosted Postgres (Neon) needs TLS; the local server does not. If unset,
  // the URL decides (Neon's URLs carry ?sslmode=require).
  databaseSsl: process.env.DATABASE_SSL === undefined ? undefined : process.env.DATABASE_SSL === 'true',
  jwtSecret: process.env.JWT_SECRET ?? (nodeEnv === 'production' ? null : 'dev-only-secret-change-me'),
  jwtExpiresIn: process.env.JWT_EXPIRES_IN ?? '7d',
  // Opening hours of rooms are stored as local times in this zone.
  timezone: process.env.APP_TIMEZONE ?? 'Asia/Kolkata',

  booking: {
    stepMinutes: int('SLOT_STEP_MINUTES', 15), // start and end must sit on this grid
    minMinutes: int('MIN_SLOT_MINUTES', 30),
    maxMinutes: int('MAX_SLOT_MINUTES', 240),
    horizonDays: int('BOOKING_HORIZON_DAYS', 7), // how far ahead you may book
    maxActivePerUser: int('MAX_ACTIVE_BOOKINGS', 3), // booked + checked-in, not yet over
    checkinEarlyMinutes: int('CHECKIN_EARLY_MINUTES', 10), // may check in this early
    checkinGraceMinutes: int('CHECKIN_GRACE_MINUTES', 15), // after start, then no-show
  },
};

if (!config.jwtSecret) {
  throw new Error('JWT_SECRET must be set in production');
}
if (config.booking.checkinGraceMinutes >= config.booking.minMinutes) {
  throw new Error('CHECKIN_GRACE_MINUTES must be shorter than MIN_SLOT_MINUTES');
}
