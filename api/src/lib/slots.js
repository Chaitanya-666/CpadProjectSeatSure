import { z } from 'zod';
import { config } from '../config.js';
import { badRequest } from './errors.js';

const MINUTE = 60 * 1000;

// ISO 8601 timestamp with an explicit offset or Z, e.g. 2026-11-02T10:00:00+05:30
const isoDateTime = z.iso.datetime({ offset: true, message: 'Use an ISO date-time like 2026-11-02T10:00:00+05:30' });

export const slotQuery = z.object({ start: isoDateTime, end: isoDateTime });

// Checks the rules that need only the clock and config. Room opening hours
// need the database and are checked in checkRoomHours below.
export function validateSlot({ start, end }, now = new Date()) {
  const s = new Date(start);
  const e = new Date(end);
  const { stepMinutes, minMinutes, maxMinutes, horizonDays } = config.booking;

  const onGrid = (d) => d.getUTCSeconds() === 0 && d.getUTCMilliseconds() === 0 && d.getUTCMinutes() % stepMinutes === 0;
  if (!onGrid(s) || !onGrid(e)) {
    throw badRequest(`Start and end must be on a ${stepMinutes}-minute boundary`);
  }
  const minutes = (e - s) / MINUTE;
  if (minutes < minMinutes) throw badRequest(`A booking must be at least ${minMinutes} minutes`);
  if (minutes > maxMinutes) throw badRequest(`A booking can be at most ${maxMinutes / 60} hours`);

  // You may book the block that is already running (e.g. 10:00 at 10:07),
  // but not one that started earlier than that.
  const currentBlockStart = new Date(Math.floor(now.getTime() / (stepMinutes * MINUTE)) * stepMinutes * MINUTE);
  if (s < currentBlockStart) throw badRequest('That time has already passed');
  if (s - now > horizonDays * 24 * 60 * MINUTE) {
    throw badRequest(`You can book at most ${horizonDays} days ahead`);
  }
  return { start: s, end: e };
}

// Is [start, end) inside the room's opening hours on a single local day?
// Done in SQL so the time zone conversion uses Postgres' tz database.
export async function checkRoomHours(db, roomId, { start, end }) {
  const { rows } = await db.query(
    `SELECT r.is_active,
            to_char(r.open_time, 'HH24:MI') AS open_time,
            to_char(r.close_time, 'HH24:MI') AS close_time,
            ($2::timestamptz AT TIME ZONE $4)::date = ($3::timestamptz AT TIME ZONE $4)::date
              AND ($2::timestamptz AT TIME ZONE $4)::time >= r.open_time
              AND ($3::timestamptz AT TIME ZONE $4)::time <= r.close_time AS within_hours
       FROM rooms r
      WHERE r.id = $1`,
    [roomId, start, end, config.timezone],
  );
  return rows[0] ?? null;
}
