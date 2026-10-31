import { config } from '../config.js';

const MINUTE = 60 * 1000;

// Columns every booking query selects, so all endpoints return one shape.
export const BOOKING_COLUMNS = `
  b.id, b.status, lower(b.slot) AS start_at, upper(b.slot) AS end_at,
  b.checked_in_at, b.ended_at, b.created_at,
  s.id AS seat_id, s.label AS seat_label, s.has_power,
  r.id AS room_id, r.name AS room_name, r.floor AS room_floor`;

export const BOOKING_FROM = `
  FROM bookings b
  JOIN seats s ON s.id = b.seat_id
  JOIN rooms r ON r.id = s.room_id`;

export function toBooking(row) {
  const start = new Date(row.start_at);
  const booking = {
    id: row.id,
    status: row.status,
    start: start.toISOString(),
    end: new Date(row.end_at).toISOString(),
    seat: { id: row.seat_id, label: row.seat_label, hasPower: row.has_power },
    room: { id: row.room_id, name: row.room_name, floor: row.room_floor },
    checkedInAt: row.checked_in_at?.toISOString() ?? null,
    endedAt: row.ended_at?.toISOString() ?? null,
    createdAt: row.created_at.toISOString(),
    checkinOpensAt: new Date(start - config.booking.checkinEarlyMinutes * MINUTE).toISOString(),
    checkinDeadline: new Date(start.getTime() + config.booking.checkinGraceMinutes * MINUTE).toISOString(),
  };
  if (row.user_id !== undefined) {
    booking.user = { id: row.user_id, name: row.user_name, email: row.user_email };
  }
  return booking;
}
