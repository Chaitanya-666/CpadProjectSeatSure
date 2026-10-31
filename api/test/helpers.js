// Shared test setup. Tests run against the real PostgreSQL test database
// (seatsure_test), because the rules that matter most (no double booking,
// lazy no-show expiry) live in SQL and cannot be checked with mocks.
import request from 'supertest';
import { createApp } from '../src/app.js';
import { pool, query } from '../src/db.js';
import { hashPassword } from '../src/lib/password.js';
import { newQrToken, signToken } from '../src/lib/tokens.js';
import { migrate } from '../scripts/migrate.js';

if (!/_test\b/.test(process.env.DATABASE_URL ?? '')) {
  throw new Error('Tests wipe the database: DATABASE_URL must point at a *_test database');
}

export const app = createApp();
export const api = () => request(app);
export { pool, query };

export async function resetDb() {
  await migrate({ log: () => {} });
  await query('TRUNCATE bookings, seats, rooms, users RESTART IDENTITY CASCADE');
}

let userCount = 0;
export async function makeUser({ role = 'student', name } = {}) {
  userCount += 1;
  const email = `user${userCount}@test.app`;
  const { rows } = await query(
    `INSERT INTO users (name, email, password_hash, role) VALUES ($1, $2, $3, $4) RETURNING id, name, email, role`,
    [name ?? `Test User ${userCount}`, email, await hashPassword('password123'), role],
  );
  const user = rows[0];
  return { ...user, token: signToken(user), auth: { Authorization: `Bearer ${signToken(user)}` } };
}

// A room open 00:00-23:59 so tests do not depend on the time of day.
export async function makeRoom({ seats = 3, open = '00:00', close = '23:59', name } = {}) {
  const room = (
    await query(`INSERT INTO rooms (name, open_time, close_time) VALUES ($1, $2, $3) RETURNING *`, [
      name ?? `Room ${Math.random().toString(36).slice(2, 8)}`,
      open,
      close,
    ])
  ).rows[0];
  const seatRows = [];
  for (let i = 1; i <= seats; i++) {
    seatRows.push(
      (
        await query(`INSERT INTO seats (room_id, label, qr_token) VALUES ($1, $2, $3) RETURNING *`, [
          room.id,
          `A${i}`,
          newQrToken(),
        ])
      ).rows[0],
    );
  }
  return { room, seats: seatRows };
}

// Local (IST, fixed +05:30) wall-clock time N days from today, as ISO.
export function istAt(daysFromToday, hhmm) {
  const todayIst = new Date(Date.now() + 5.5 * 3600 * 1000);
  todayIst.setUTCDate(todayIst.getUTCDate() + daysFromToday);
  return `${todayIst.toISOString().slice(0, 10)}T${hhmm}:00+05:30`;
}

// Insert a booking directly with any slot (bypasses the API's time rules),
// for tests that need a slot around "now".
export async function insertBooking({ seatId, userId, startMinutesFromNow, minutes = 60, status = 'booked' }) {
  const { rows } = await query(
    `INSERT INTO bookings (seat_id, user_id, slot, status)
     VALUES ($1, $2, tstzrange(now() + make_interval(mins => $3), now() + make_interval(mins => $4), '[)'), $5)
     RETURNING *`,
    [seatId, userId, startMinutesFromNow, startMinutesFromNow + minutes, status],
  );
  return rows[0];
}
