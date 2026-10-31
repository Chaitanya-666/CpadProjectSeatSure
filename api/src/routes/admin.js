import { Router } from 'express';
import { z } from 'zod';
import { config } from '../config.js';
import { query, withTransaction } from '../db.js';
import { badRequest, notFound } from '../lib/errors.js';
import { BOOKING_COLUMNS, BOOKING_FROM, toBooking } from '../lib/bookingView.js';
import { newQrToken } from '../lib/tokens.js';
import { requireAdmin, requireAuth } from '../middleware/auth.js';
import { noShowSweep } from '../middleware/noShowSweep.js';

export const adminRouter = Router();
adminRouter.use(requireAuth, requireAdmin, noShowSweep);

const idParam = z.object({ id: z.coerce.number().int().positive() });
const hhmm = z.string().regex(/^([01]\d|2[0-3]):[0-5]\d$/, 'Use HH:MM (24-hour)');

const roomBody = z.object({
  name: z.string().trim().min(2).max(80),
  description: z.string().trim().max(300).default(''),
  floor: z.string().trim().max(40).default(''),
  openTime: hhmm.default('08:00'),
  closeTime: hhmm.default('22:00'),
});

const ROOM_COLUMNS = `r.id, r.name, r.description, r.floor, r.is_active,
  to_char(r.open_time, 'HH24:MI') AS open_time, to_char(r.close_time, 'HH24:MI') AS close_time`;

const toRoom = (r) => ({
  id: r.id,
  name: r.name,
  description: r.description,
  floor: r.floor,
  openTime: r.open_time,
  closeTime: r.close_time,
  isActive: r.is_active,
  seatCount: r.seat_count ?? undefined,
});

const toSeat = (s) => ({ id: s.id, roomId: s.room_id, label: s.label, hasPower: s.has_power, qrToken: s.qr_token, isActive: s.is_active });

// ---- rooms ----

adminRouter.get('/rooms', async (_req, res) => {
  const { rows } = await query(
    `SELECT ${ROOM_COLUMNS}, count(s.id) FILTER (WHERE s.is_active)::int AS seat_count
       FROM rooms r LEFT JOIN seats s ON s.room_id = r.id
      GROUP BY r.id ORDER BY r.name`,
  );
  res.json({ rooms: rows.map(toRoom) });
});

adminRouter.post('/rooms', async (req, res) => {
  const b = roomBody.parse(req.body);
  if (b.openTime >= b.closeTime) throw badRequest('Opening time must be before closing time');
  const { rows } = await query(
    `INSERT INTO rooms AS r (name, description, floor, open_time, close_time)
     VALUES ($1, $2, $3, $4, $5) RETURNING ${ROOM_COLUMNS}`,
    [b.name, b.description, b.floor, b.openTime, b.closeTime],
  );
  res.status(201).json({ room: toRoom(rows[0]) });
});

adminRouter.patch('/rooms/:id', async (req, res) => {
  const { id } = idParam.parse(req.params);
  const b = roomBody.partial().extend({ isActive: z.boolean().optional() }).parse(req.body);
  // COALESCE keeps the old value for every field the client did not send.
  const { rows } = await query(
    `UPDATE rooms AS r SET
        name        = COALESCE($2, name),
        description = COALESCE($3, description),
        floor       = COALESCE($4, floor),
        open_time   = COALESCE($5::time, open_time),
        close_time  = COALESCE($6::time, close_time),
        is_active   = COALESCE($7, is_active)
      WHERE id = $1 RETURNING ${ROOM_COLUMNS}`,
    [id, b.name, b.description, b.floor, b.openTime, b.closeTime, b.isActive],
  );
  if (rows.length === 0) throw notFound('Room not found');
  res.json({ room: toRoom(rows[0]) });
});

// ---- seats ----

adminRouter.get('/rooms/:id/seats', async (req, res) => {
  const { id } = idParam.parse(req.params);
  const { rows } = await query('SELECT * FROM seats WHERE room_id = $1 ORDER BY label', [id]);
  res.json({ seats: rows.map(toSeat) });
});

// Add seats in bulk, e.g. { prefix: "B", from: 1, count: 6 } -> B1..B6,
// or an explicit { labels: ["W1", "W2"] }. All or nothing (one transaction).
const addSeatsBody = z.union([
  z.object({
    labels: z.array(z.string().trim().min(1).max(10)).min(1).max(100),
    hasPower: z.boolean().default(false),
  }),
  z.object({
    prefix: z.string().trim().max(5).default(''),
    from: z.number().int().min(0).default(1),
    count: z.number().int().min(1).max(100),
    hasPower: z.boolean().default(false),
  }),
]);

adminRouter.post('/rooms/:id/seats', async (req, res) => {
  const { id } = idParam.parse(req.params);
  const b = addSeatsBody.parse(req.body);
  const labels = b.labels ?? Array.from({ length: b.count }, (_, i) => `${b.prefix}${b.from + i}`);

  const seats = await withTransaction(async (db) => {
    const room = await db.query('SELECT id FROM rooms WHERE id = $1', [id]);
    if (room.rowCount === 0) throw notFound('Room not found');
    const created = [];
    for (const label of labels) {
      const { rows } = await db.query(
        `INSERT INTO seats (room_id, label, has_power, qr_token) VALUES ($1, $2, $3, $4) RETURNING *`,
        [id, label, b.hasPower, newQrToken()],
      );
      created.push(rows[0]);
    }
    return created;
  });
  res.status(201).json({ seats: seats.map(toSeat) });
});

adminRouter.patch('/seats/:id', async (req, res) => {
  const { id } = idParam.parse(req.params);
  const b = z
    .object({
      label: z.string().trim().min(1).max(10).optional(),
      hasPower: z.boolean().optional(),
      isActive: z.boolean().optional(),
    })
    .parse(req.body);
  const { rows } = await query(
    `UPDATE seats SET label = COALESCE($2, label), has_power = COALESCE($3, has_power),
                      is_active = COALESCE($4, is_active)
      WHERE id = $1 RETURNING *`,
    [id, b.label, b.hasPower, b.isActive],
  );
  if (rows.length === 0) throw notFound('Seat not found');
  res.json({ seat: toSeat(rows[0]) });
});

// New QR code for a seat (e.g. a photo of the old one was shared around).
// The old printed code stops working at once.
adminRouter.post('/seats/:id/rotate-qr', async (req, res) => {
  const { id } = idParam.parse(req.params);
  const { rows } = await query('UPDATE seats SET qr_token = $2 WHERE id = $1 RETURNING *', [id, newQrToken()]);
  if (rows.length === 0) throw notFound('Seat not found');
  res.json({ seat: toSeat(rows[0]) });
});

// ---- bookings and stats ----

// Every booking on one local day, with who made it.
adminRouter.get('/bookings', async (req, res) => {
  const q = z
    .object({ date: z.iso.date(), roomId: z.coerce.number().int().positive().optional() })
    .parse(req.query);
  const { rows } = await query(
    `SELECT ${BOOKING_COLUMNS}, u.id AS user_id, u.name AS user_name, u.email AS user_email
       ${BOOKING_FROM}
       JOIN users u ON u.id = b.user_id
      WHERE b.slot && tstzrange(($1::date)::timestamp AT TIME ZONE $2,
                                ($1::date + 1)::timestamp AT TIME ZONE $2, '[)')
        AND ($3::int IS NULL OR r.id = $3)
      ORDER BY lower(b.slot), r.name, s.label`,
    [q.date, config.timezone, q.roomId ?? null],
  );
  res.json({ bookings: rows.map(toBooking) });
});

// Dashboard numbers for the last N days (default 7), all from SQL aggregates.
adminRouter.get('/stats', async (req, res) => {
  const { days } = z.object({ days: z.coerce.number().int().min(1).max(90).default(7) }).parse(req.query);
  const params = [days, config.timezone];
  const window = `lower(b.slot) >= now() - make_interval(days => $1) AND lower(b.slot) < now()`;

  const [now, perRoom, byHour, totals] = await Promise.all([
    // Right now: seats in use (checked in) and held (booked, waiting).
    query(
      `SELECT count(*) FILTER (WHERE status = 'checked_in')::int AS in_use,
              count(*) FILTER (WHERE status = 'booked')::int AS held,
              (SELECT count(*)::int FROM seats WHERE is_active) AS seats
         FROM bookings WHERE slot @> now()`,
    ),
    // Per room: bookings that have started in the window, and how they ended.
    query(
      `SELECT r.id, r.name,
              count(b.id)::int AS bookings,
              count(b.id) FILTER (WHERE b.status = 'no_show')::int AS no_shows,
              count(b.id) FILTER (WHERE b.status = 'cancelled')::int AS cancelled,
              count(b.id) FILTER (WHERE b.checked_in_at IS NOT NULL)::int AS attended,
              round(COALESCE(sum(extract(epoch FROM
                 LEAST(COALESCE(b.ended_at, upper(b.slot)), upper(b.slot), now()) - b.checked_in_at
              )) FILTER (WHERE b.checked_in_at IS NOT NULL), 0) / 3600.0, 1)::float AS hours_used
         FROM rooms r
         LEFT JOIN seats s ON s.room_id = r.id
         LEFT JOIN bookings b ON b.seat_id = s.id AND ${window}
        GROUP BY r.id ORDER BY r.name`,
      [days],
    ),
    // Busiest start hours (local time), for the bar chart.
    query(
      `SELECT extract(hour FROM lower(b.slot) AT TIME ZONE $2)::int AS hour, count(*)::int AS bookings
         FROM bookings b WHERE ${window} AND b.status <> 'cancelled'
        GROUP BY 1 ORDER BY 1`,
      params,
    ),
    query(`SELECT (SELECT count(*)::int FROM users WHERE role = 'student') AS students`),
  ]);

  const rooms = perRoom.rows.map((r) => {
    const decided = r.bookings - r.cancelled; // cancelled ones never had a chance to show
    return {
      id: r.id,
      name: r.name,
      bookings: r.bookings,
      attended: r.attended,
      noShows: r.no_shows,
      cancelled: r.cancelled,
      noShowRate: decided > 0 ? Number((r.no_shows / decided).toFixed(3)) : 0,
      hoursUsed: r.hours_used,
    };
  });
  res.json({
    days,
    now: { inUse: now.rows[0].in_use, held: now.rows[0].held, seats: now.rows[0].seats },
    students: totals.rows[0].students,
    rooms,
    byHour: byHour.rows,
  });
});
