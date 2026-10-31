import { config } from '../config.js';
import { query } from '../db.js';

// Lazy expiry of no-shows.
// A free Render server sleeps when idle, so a timer inside the API cannot be
// trusted to release seats on time. Instead, before any request that reads or
// changes bookings, one UPDATE marks every booking whose check-in window has
// closed as no_show. The exclusion constraint ignores no_show rows, so the
// seat is free again immediately. Correct even if the server slept for hours.
export async function sweepNoShows(db = { query }) {
  const { rowCount } = await db.query(
    `UPDATE bookings
        SET status = 'no_show'
      WHERE status = 'booked'
        AND lower(slot) + make_interval(mins => $1) <= now()`,
    [config.booking.checkinGraceMinutes],
  );
  return rowCount;
}

export async function noShowSweep(_req, _res, next) {
  await sweepNoShows();
  next();
}
