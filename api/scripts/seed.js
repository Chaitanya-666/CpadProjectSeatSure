// Demo data.
//   npm run seed                  full reset: users, rooms, seats, bookings
//   npm run seed -- --bookings    keep users/rooms/seats (so printed QR codes
//                                 stay valid), redo only the bookings
// Booking history is random but repeatable (fixed PRNG seed), so the admin
// dashboard looks the same after every reset.
import { fileURLToPath } from 'node:url';
import { config } from '../src/config.js';
import { pool, withTransaction } from '../src/db.js';
import { hashPassword } from '../src/lib/password.js';
import { newQrToken } from '../src/lib/tokens.js';
import { migrate } from './migrate.js';

// The repo is public, so the default demo passwords below are public too.
// They are fine on a laptop, but a hosted database (Neon) must get private
// passwords from SEED_ADMIN_PASSWORD / SEED_STUDENT_PASSWORD (kept in the
// git-ignored api/.env.neon), or seeding refuses to run.
const isLocalDb = /@(localhost|127\.0\.0\.1|\[::1\])(:|\/)/.test(config.databaseUrl);
const adminPassword = process.env.SEED_ADMIN_PASSWORD ?? 'Admin@1234';
const studentPassword = process.env.SEED_STUDENT_PASSWORD ?? 'Student@123';

export const DEMO = {
  admin: { name: 'Library Admin', email: 'admin@seatsure.app', password: adminPassword },
  students: [
    { name: 'Chaitanya Shinde', email: 'chaitanya@seatsure.app', password: studentPassword },
    { name: 'Riya Patil', email: 'riya@seatsure.app', password: studentPassword },
  ],
};

function assertSafePasswords() {
  if (isLocalDb) return;
  const missing = ['SEED_ADMIN_PASSWORD', 'SEED_STUDENT_PASSWORD'].filter((k) => !process.env[k]);
  const weak = [adminPassword, studentPassword].some((p) => p.length < 12);
  if (missing.length || weak) {
    throw new Error(
      `Refusing to seed a hosted database with public demo passwords. ` +
        `Set ${missing.length ? missing.join(' and ') : 'longer (12+ chars) SEED_*_PASSWORD values'} in the env file.`,
    );
  }
}

const ROOMS = [
  {
    name: 'Central Reading Hall',
    description: 'Main hall, long tables. Row C has power sockets.',
    floor: 'Ground floor',
    open: '08:00',
    close: '22:00',
    rows: [
      ['A', 8, false],
      ['B', 8, false],
      ['C', 8, true],
    ],
  },
  {
    name: 'Silent Study Zone',
    description: 'No talking, no calls. Single desks.',
    floor: 'First floor',
    open: '08:00',
    close: '20:00',
    rows: [['S', 12, false]],
  },
  {
    name: 'Digital Library Lab',
    description: 'Desks with power and wired LAN.',
    floor: 'Second floor',
    open: '09:00',
    close: '18:00',
    rows: [['D', 10, true]],
  },
];

const FAKE_NAMES = [
  'Aarav Mehta', 'Ishita Rao', 'Kabir Singh', 'Sneha Kulkarni', 'Rohan Desai', 'Ananya Iyer',
  'Vihaan Joshi', 'Diya Nair', 'Arjun Pawar', 'Meera Shah', 'Aditya Kale', 'Pooja Gupta',
  'Siddharth Jain', 'Tanvi More', 'Yash Bhosale', 'Neha Chavan', 'Om Deshmukh', 'Kavya Reddy',
];

// mulberry32: tiny seeded PRNG, same numbers every run.
function prng(seed) {
  return () => {
    seed = (seed + 0x6d2b79f5) | 0;
    let t = Math.imul(seed ^ (seed >>> 15), 1 | seed);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

const MIN = 60 * 1000;
const pick = (rand, arr) => arr[Math.floor(rand() * arr.length)];

// Local wall-clock time in APP_TIMEZONE -> UTC Date, via Postgres.
async function localToUtc(db, date, hhmm) {
  const { rows } = await db.query(`SELECT (($1::date + $2::time)::timestamp AT TIME ZONE $3) AS t`, [
    date,
    hhmm,
    config.timezone,
  ]);
  return rows[0].t;
}

async function seedUsersRoomsSeats(db, log) {
  await db.query('TRUNCATE bookings, seats, rooms, users RESTART IDENTITY CASCADE');

  const users = [
    { ...DEMO.admin, role: 'admin' },
    ...DEMO.students.map((s) => ({ ...s, role: 'student' })),
    ...FAKE_NAMES.map((name) => ({
      name,
      email: `${name.toLowerCase().replace(/ /g, '.')}@seatsure.app`,
      password: studentPassword,
      role: 'student',
    })),
  ];
  for (const u of users) {
    await db.query('INSERT INTO users (name, email, password_hash, role) VALUES ($1, $2, $3, $4)', [
      u.name,
      u.email,
      await hashPassword(u.password),
      u.role,
    ]);
  }

  for (const room of ROOMS) {
    const { rows } = await db.query(
      `INSERT INTO rooms (name, description, floor, open_time, close_time)
       VALUES ($1, $2, $3, $4, $5) RETURNING id`,
      [room.name, room.description, room.floor, room.open, room.close],
    );
    for (const [prefix, count, power] of room.rows) {
      for (let i = 1; i <= count; i++) {
        await db.query('INSERT INTO seats (room_id, label, has_power, qr_token) VALUES ($1, $2, $3, $4)', [
          rows[0].id,
          `${prefix}${i}`,
          power,
          newQrToken(),
        ]);
      }
    }
  }
  log(`users: ${users.length}, rooms: ${ROOMS.length}`);
}

async function seedBookings(db, log) {
  await db.query('TRUNCATE bookings RESTART IDENTITY');
  const rand = prng(20261031);

  const seats = (
    await db.query(
      `SELECT s.id, to_char(r.open_time, 'HH24:MI') AS open, to_char(r.close_time, 'HH24:MI') AS close
         FROM seats s JOIN rooms r ON r.id = s.room_id ORDER BY s.id`,
    )
  ).rows;
  // History uses the fake students only; the two demo students start clean.
  const fakeIds = (
    await db.query(`SELECT id FROM users WHERE role = 'student' AND email NOT IN ($1, $2) ORDER BY id`, [
      DEMO.students[0].email,
      DEMO.students[1].email,
    ])
  ).rows.map((r) => r.id);

  const today = (await db.query(`SELECT (now() AT TIME ZONE $1)::date::text AS d`, [config.timezone])).rows[0].d;
  const now = new Date();
  const busySeat = new Map(); // seat id -> [[start, end]] of live rows
  const busyUser = new Map();
  const overlaps = (map, key, s, e) => (map.get(key) ?? []).some(([a, b]) => s < b && a < e);
  const mark = (map, key, s, e) => map.set(key, [...(map.get(key) ?? []), [s, e]]);

  let made = 0;
  for (let dayOffset = -7; dayOffset <= 0; dayOffset++) {
    const date = new Date(`${today}T00:00:00Z`);
    date.setUTCDate(date.getUTCDate() + dayOffset);
    const day = date.toISOString().slice(0, 10);
    const target = dayOffset === 0 ? 14 : 30 + Math.floor(rand() * 25);

    for (let n = 0, tries = 0; n < target && tries < target * 10; tries++) {
      const seat = pick(rand, seats);
      const user = pick(rand, fakeIds);
      const openH = Number(seat.open.slice(0, 2));
      const closeH = Number(seat.close.slice(0, 2));
      const hours = 1 + Math.floor(rand() * 3);
      if (closeH - openH <= hours) continue;
      const startH = openH + Math.floor(rand() * (closeH - openH - hours));
      const startMin = pick(rand, ['00', '30']);
      const start = await localToUtc(db, day, `${String(startH).padStart(2, '0')}:${startMin}`);
      const end = new Date(start.getTime() + hours * 60 * MIN);
      if (end > (await localToUtc(db, day, seat.close))) continue;

      // Status follows from where the slot sits relative to now.
      const r = rand();
      let status;
      let checkedIn = null;
      let ended = null;
      if (end <= now) {
        if (r < 0.15) status = 'cancelled';
        else if (r < 0.32) status = 'no_show';
        else {
          checkedIn = new Date(start.getTime() + Math.floor(rand() * 12) * MIN);
          if (r < 0.5) {
            status = 'completed';
            ended = new Date(end.getTime() - (15 + Math.floor(rand() * 30)) * MIN);
          } else status = 'checked_in';
        }
      } else if (start <= now) {
        // Running now. Started more than the grace period ago -> must have checked in.
        if (now - start < config.booking.checkinGraceMinutes * MIN && r < 0.5) status = 'booked';
        else {
          status = 'checked_in';
          checkedIn = new Date(start.getTime() + 2 * MIN);
        }
      } else {
        status = r < 0.1 ? 'cancelled' : 'booked';
      }

      const live = status === 'booked' || status === 'checked_in';
      if (live && (overlaps(busySeat, seat.id, start, end) || overlaps(busyUser, user, start, end))) continue;
      if (live) {
        mark(busySeat, seat.id, start, end);
        mark(busyUser, user, start, end);
      }
      await db.query(
        `INSERT INTO bookings (seat_id, user_id, slot, status, checked_in_at, ended_at, created_at)
         VALUES ($1, $2, tstzrange($3, $4, '[)'), $5, $6, $7, $8)`,
        [seat.id, user, start, end, status, checkedIn, ended, new Date(start.getTime() - 6 * 60 * MIN)],
      );
      n++;
      made++;
    }
  }
  log(`bookings: ${made}`);
}

export async function seed({ bookingsOnly = false, log = console.log } = {}) {
  if (!bookingsOnly) assertSafePasswords();
  await migrate({ log });
  await withTransaction(async (db) => {
    if (!bookingsOnly) await seedUsersRoomsSeats(db, log);
    await seedBookings(db, log);
  });
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  seed({ bookingsOnly: process.argv.includes('--bookings') })
    .then(() => {
      console.log('\nDemo logins:');
      // Never print the hosted database's passwords (terminal logs get shared).
      const show = (p) => (isLocalDb ? p : '(from SEED_*_PASSWORD in your env file)');
      console.log(`  admin    ${DEMO.admin.email} / ${show(DEMO.admin.password)}`);
      for (const s of DEMO.students) console.log(`  student  ${s.email} / ${show(s.password)}`);
    })
    .catch((err) => {
      console.error(err);
      process.exitCode = 1;
    })
    .finally(() => pool.end());
}
