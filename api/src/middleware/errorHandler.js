import { ZodError } from 'zod';
import { ApiError } from '../lib/errors.js';

// Postgres error codes that are really client mistakes, mapped to friendly
// 409/400 responses. Constraint names come from migrations/001_init.sql.
const constraintMessages = {
  no_seat_overlap: ['seat_taken', 'That seat is already booked for part of this time'],
  no_user_overlap: ['you_have_overlap', 'You already have a booking that overlaps this time'],
  users_email_unique: ['email_taken', 'An account with this email already exists'],
  rooms_name_key: ['room_exists', 'A room with this name already exists'],
  seats_room_id_label_key: ['seat_exists', 'A seat with this label already exists in the room'],
};

export function notFoundHandler(req, res) {
  res.status(404).json({ error: { code: 'not_found', message: `No route for ${req.method} ${req.path}` } });
}

export function errorHandler(err, _req, res, _next) {
  if (err instanceof ZodError) {
    const details = err.issues.map((i) => ({ path: i.path.join('.'), message: i.message }));
    return res.status(400).json({
      error: { code: 'validation', message: details[0]?.message ?? 'Invalid input', details },
    });
  }
  if (err instanceof ApiError) {
    return res.status(err.status).json({ error: { code: err.code, message: err.message, details: err.details } });
  }
  // 23P01 exclusion_violation, 23505 unique_violation
  if ((err.code === '23P01' || err.code === '23505') && constraintMessages[err.constraint]) {
    const [code, message] = constraintMessages[err.constraint];
    return res.status(409).json({ error: { code, message } });
  }
  if (err.type === 'entity.parse.failed') {
    return res.status(400).json({ error: { code: 'bad_json', message: 'Request body is not valid JSON' } });
  }
  console.error(err);
  res.status(500).json({ error: { code: 'internal', message: 'Something went wrong on the server' } });
}
