import { Router } from 'express';
import { z } from 'zod';
import { config } from '../config.js';
import { query, withTransaction } from '../db.js';
import { badRequest, conflict, notFound } from '../lib/errors.js';
import { BOOKING_COLUMNS, BOOKING_FROM, toBooking } from '../lib/bookingView.js';
import { checkRoomHours, slotQuery, validateSlot } from '../lib/slots.js';
import { requireAuth } from '../middleware/auth.js';
import { noShowSweep, sweepNoShows } from '../middleware/noShowSweep.js';

export const bookingsRouter = Router();
bookingsRouter.use(requireAuth, noShowSweep);

const createBody = slotQuery.extend({ seatId: z.coerce.number().int().positive() });
const idParam = z.object({ id: z.coerce.number().int().positive() });

async function loadOwnBooking(db, id, userId) {
  const { rows } = await db.query(`SELECT ${BOOKING_COLUMNS} ${BOOKING_FROM} WHERE b.id = $1 AND b.user_id = $2`, [
    id,
    userId,
  ]);
  if (rows.length === 0) throw notFound('Booking not found');
  return rows[0];
}

// Book a seat.
// The order matters:
//   1. lock this user's row, so two parallel requests from the same student
//      run one after the other (otherwise both could pass the limit check);
//   2. sweep no-shows inside the same transaction, so a seat released a
//      second ago is bookable;
//   3. check the seat, the room hours and the per-student limit;
//   4. INSERT. If another student grabbed an overlapping slot, the
//      no_seat_overlap exclusion constraint rejects the row (409). The
//      database is the final judge, not the "free" colour the app showed.
bookingsRouter.post('/', async (req, res) => {
  const body = createBody.parse(req.body);
  const slot = validateSlot(body);

  const booking = await withTransaction(async (db) => {
    await db.query('SELECT id FROM users WHERE id = $1 FOR UPDATE', [req.user.id]);
    await sweepNoShows(db);

    const seat = await db.query('SELECT id, room_id, is_active FROM seats WHERE id = $1', [body.seatId]);
    if (seat.rowCount === 0 || !seat.rows[0].is_active) throw notFound('Seat not found');

    const room = await checkRoomHours(db, seat.rows[0].room_id, slot);
    if (!room?.is_active) throw notFound('Room not found');
    if (!room.within_hours) {
      throw badRequest(`This room is open ${room.open_time}–${room.close_time}; pick a time inside that on one day`);
    }

    const active = await db.query(
      `SELECT count(*)::int AS n FROM bookings
        WHERE user_id = $1 AND status IN ('booked', 'checked_in') AND upper(slot) > now()`,
      [req.user.id],
    );
    if (active.rows[0].n >= config.booking.maxActivePerUser) {
      throw conflict(
        'limit_reached',
        `You can hold at most ${config.booking.maxActivePerUser} upcoming bookings; cancel one first`,
      );
    }

    const inserted = await db.query(
      `INSERT INTO bookings (seat_id, user_id, slot)
       VALUES ($1, $2, tstzrange($3, $4, '[)'))
       RETURNING id`,
      [body.seatId, req.user.id, slot.start, slot.end],
    );
    return loadOwnBooking(db, inserted.rows[0].id, req.user.id);
  });

  res.status(201).json({ booking: toBooking(booking) });
});

// My bookings. upcoming = not over yet and still live; history = the rest.
bookingsRouter.get('/me', async (req, res) => {
  const { scope } = z.object({ scope: z.enum(['upcoming', 'history']).default('upcoming') }).parse(req.query);
  const where =
    scope === 'upcoming'
      ? `b.status IN ('booked', 'checked_in') AND upper(b.slot) > now()`
      : `NOT (b.status IN ('booked', 'checked_in') AND upper(b.slot) > now())`;
  const order = scope === 'upcoming' ? 'lower(b.slot) ASC' : 'lower(b.slot) DESC';
  const { rows } = await query(
    `SELECT ${BOOKING_COLUMNS} ${BOOKING_FROM}
      WHERE b.user_id = $1 AND ${where}
      ORDER BY ${order}
      LIMIT 50`,
    [req.user.id],
  );
  res.json({ bookings: rows.map(toBooking) });
});

// Cancel a booking that has not been checked in yet.
bookingsRouter.post('/:id/cancel', async (req, res) => {
  const { id } = idParam.parse(req.params);
  const booking = await withTransaction(async (db) => {
    const current = await loadOwnBooking(db, id, req.user.id);
    if (current.status !== 'booked') {
      throw conflict('not_cancellable', `A ${current.status.replace('_', ' ')} booking cannot be cancelled`);
    }
    await db.query(`UPDATE bookings SET status = 'cancelled' WHERE id = $1`, [id]);
    return loadOwnBooking(db, id, req.user.id);
  });
  res.json({ booking: toBooking(booking) });
});

// Leave early: the seat is free for others from now on. The original slot is
// kept for the record; completed rows drop out of the overlap constraint.
bookingsRouter.post('/:id/checkout', async (req, res) => {
  const { id } = idParam.parse(req.params);
  const booking = await withTransaction(async (db) => {
    const current = await loadOwnBooking(db, id, req.user.id);
    if (current.status !== 'checked_in' || new Date(current.end_at) <= new Date()) {
      throw conflict('not_checked_in', 'Only a running, checked-in booking can be checked out');
    }
    await db.query(`UPDATE bookings SET status = 'completed', ended_at = now() WHERE id = $1`, [id]);
    return loadOwnBooking(db, id, req.user.id);
  });
  res.json({ booking: toBooking(booking) });
});
