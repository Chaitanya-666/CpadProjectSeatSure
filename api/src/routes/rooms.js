import { Router } from 'express';
import { z } from 'zod';
import { config } from '../config.js';
import { query } from '../db.js';
import { notFound } from '../lib/errors.js';
import { slotQuery } from '../lib/slots.js';
import { requireAuth } from '../middleware/auth.js';
import { noShowSweep } from '../middleware/noShowSweep.js';

export const roomsRouter = Router();
roomsRouter.use(requireAuth, noShowSweep);

const LIVE = `status IN ('booked', 'checked_in')`;
const idParam = z.object({ id: z.coerce.number().int().positive() });

// All open rooms with how many seats are free right now.
roomsRouter.get('/', async (_req, res) => {
  const { rows } = await query(
    `SELECT r.id, r.name, r.description, r.floor,
            to_char(r.open_time, 'HH24:MI') AS open_time,
            to_char(r.close_time, 'HH24:MI') AS close_time,
            count(s.id)::int AS seat_count,
            count(s.id) FILTER (
              WHERE NOT EXISTS (
                SELECT 1 FROM bookings b
                 WHERE b.seat_id = s.id AND b.${LIVE} AND b.slot @> now()
              )
            )::int AS free_now
       FROM rooms r
       LEFT JOIN seats s ON s.room_id = r.id AND s.is_active
      WHERE r.is_active
      GROUP BY r.id
      ORDER BY r.name`,
  );
  res.json({
    rooms: rows.map((r) => ({
      id: r.id,
      name: r.name,
      description: r.description,
      floor: r.floor,
      openTime: r.open_time,
      closeTime: r.close_time,
      seatCount: r.seat_count,
      freeNow: r.free_now,
    })),
  });
});

// Seat map for one time slot: each seat is free, taken, or mine.
// Who booked a taken seat is not shown to other students.
roomsRouter.get('/:id/availability', async (req, res) => {
  const { id } = idParam.parse(req.params);
  const { start, end } = slotQuery.parse(req.query);
  const room = await query('SELECT id FROM rooms WHERE id = $1 AND is_active', [id]);
  if (room.rowCount === 0) throw notFound('Room not found');

  const { rows } = await query(
    `SELECT s.id, s.label, s.has_power,
            b.id AS booking_id, b.user_id
       FROM seats s
       LEFT JOIN LATERAL (
         SELECT id, user_id FROM bookings
          WHERE seat_id = s.id AND ${LIVE} AND slot && tstzrange($2, $3, '[)')
          LIMIT 1
       ) b ON true
      WHERE s.room_id = $1 AND s.is_active
      ORDER BY s.label`,
    [id, start, end],
  );
  res.json({
    roomId: id,
    start: new Date(start).toISOString(),
    end: new Date(end).toISOString(),
    seats: rows.map((s) => ({
      id: s.id,
      label: s.label,
      hasPower: s.has_power,
      state: s.booking_id === null ? 'free' : s.user_id === req.user.id ? 'mine' : 'taken',
    })),
  });
});

// Busy intervals per seat for one local day, for the timeline view.
roomsRouter.get('/:id/timeline', async (req, res) => {
  const { id } = idParam.parse(req.params);
  const { date } = z.object({ date: z.iso.date() }).parse(req.query);
  const room = await query('SELECT id FROM rooms WHERE id = $1 AND is_active', [id]);
  if (room.rowCount === 0) throw notFound('Room not found');

  const { rows } = await query(
    `SELECT s.id, s.label, b.start_at, b.end_at, b.user_id, b.status
       FROM seats s
       LEFT JOIN LATERAL (
         SELECT lower(slot) AS start_at, upper(slot) AS end_at, user_id, status
           FROM bookings
          WHERE seat_id = s.id AND ${LIVE}
            AND slot && tstzrange(($2::date)::timestamp AT TIME ZONE $3,
                                  ($2::date + 1)::timestamp AT TIME ZONE $3, '[)')
       ) b ON true
      WHERE s.room_id = $1 AND s.is_active
      ORDER BY s.label, b.start_at`,
    [id, date, config.timezone],
  );
  const seats = new Map();
  for (const r of rows) {
    if (!seats.has(r.id)) seats.set(r.id, { id: r.id, label: r.label, busy: [] });
    if (r.start_at) {
      seats.get(r.id).busy.push({
        start: r.start_at.toISOString(),
        end: r.end_at.toISOString(),
        mine: r.user_id === req.user.id,
        status: r.status,
      });
    }
  }
  res.json({ roomId: id, date, seats: [...seats.values()] });
});
