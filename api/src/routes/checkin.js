import { Router } from 'express';
import { z } from 'zod';
import { config } from '../config.js';
import { withTransaction } from '../db.js';
import { conflict, notFound } from '../lib/errors.js';
import { BOOKING_COLUMNS, BOOKING_FROM, toBooking } from '../lib/bookingView.js';
import { requireAuth } from '../middleware/auth.js';
import { noShowSweep } from '../middleware/noShowSweep.js';

export const checkinRouter = Router();
checkinRouter.use(requireAuth, noShowSweep);

const body = z.object({ qrToken: z.string().trim().min(1, 'Scan the QR code on the seat') });

const timeIn = (d) =>
  new Date(d).toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit', timeZone: config.timezone });

// Check in by scanning the QR code stuck on the seat.
// The student sends only the scanned token; the server finds their booking
// for that seat whose check-in window [start - early, start + grace) is open.
checkinRouter.post('/', async (req, res) => {
  const { qrToken } = body.parse(req.body);
  const { checkinEarlyMinutes: early, checkinGraceMinutes: grace } = config.booking;

  const booking = await withTransaction(async (db) => {
    const seat = await db.query(
      `SELECT s.id, s.label, r.name AS room_name
         FROM seats s JOIN rooms r ON r.id = s.room_id
        WHERE s.qr_token = $1 AND s.is_active`,
      [qrToken],
    );
    if (seat.rowCount === 0) throw notFound('This QR code is not a SeatSure seat');
    const seatId = seat.rows[0].id;

    // FOR UPDATE: two taps on "check in" at once cannot both succeed.
    const due = await db.query(
      `SELECT b.id FROM bookings b
        WHERE b.user_id = $1 AND b.seat_id = $2 AND b.status = 'booked'
          AND now() >= lower(b.slot) - make_interval(mins => $3)
          AND now() <  lower(b.slot) + make_interval(mins => $4)
        FOR UPDATE`,
      [req.user.id, seatId, early, grace],
    );
    if (due.rowCount > 0) {
      await db.query(`UPDATE bookings SET status = 'checked_in', checked_in_at = now() WHERE id = $1`, [
        due.rows[0].id,
      ]);
      const { rows } = await db.query(`SELECT ${BOOKING_COLUMNS} ${BOOKING_FROM} WHERE b.id = $1`, [due.rows[0].id]);
      return rows[0];
    }

    // Nothing to check in: work out the most helpful reason.
    const already = await db.query(
      `SELECT 1 FROM bookings WHERE user_id = $1 AND seat_id = $2 AND status = 'checked_in' AND slot @> now()`,
      [req.user.id, seatId],
    );
    if (already.rowCount > 0) throw conflict('already_checked_in', 'You are already checked in at this seat');

    const later = await db.query(
      `SELECT lower(slot) AS start_at FROM bookings
        WHERE user_id = $1 AND seat_id = $2 AND status = 'booked' AND lower(slot) > now()
        ORDER BY lower(slot) LIMIT 1`,
      [req.user.id, seatId],
    );
    if (later.rowCount > 0) {
      const opens = new Date(later.rows[0].start_at.getTime() - early * 60 * 1000);
      throw conflict('too_early', `Too early: check-in for this seat opens at ${timeIn(opens)}`);
    }

    const elsewhere = await db.query(
      `SELECT ${BOOKING_COLUMNS} ${BOOKING_FROM}
        WHERE b.user_id = $1 AND b.status = 'booked'
          AND now() >= lower(b.slot) - make_interval(mins => $2)
          AND now() <  lower(b.slot) + make_interval(mins => $3)
        LIMIT 1`,
      [req.user.id, early, grace],
    );
    if (elsewhere.rowCount > 0) {
      const b = elsewhere.rows[0];
      throw conflict('wrong_seat', `Wrong seat: your booking is for seat ${b.seat_label} in ${b.room_name}`);
    }

    const missed = await db.query(
      `SELECT 1 FROM bookings
        WHERE user_id = $1 AND seat_id = $2 AND status = 'no_show' AND upper(slot) > now()`,
      [req.user.id, seatId],
    );
    if (missed.rowCount > 0) {
      throw conflict('checkin_closed', `Check-in closed ${grace} minutes after the start, so the seat was released`);
    }
    throw conflict('no_booking', `You have no booking for seat ${seat.rows[0].label} right now`);
  });

  res.json({ booking: toBooking(booking) });
});
