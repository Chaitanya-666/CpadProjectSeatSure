import { randomBytes } from 'node:crypto';
import jwt from 'jsonwebtoken';
import { config } from '../config.js';

export function signToken(user) {
  return jwt.sign({ sub: String(user.id), role: user.role }, config.jwtSecret, {
    expiresIn: config.jwtExpiresIn,
  });
}

export function verifyToken(token) {
  return jwt.verify(token, config.jwtSecret, { algorithms: ['HS256'] });
}

// Seat QR payload. Random, so nobody can guess another seat's code from its
// label; the app reads it from the printed QR on the desk.
export function newQrToken() {
  return `seat_${randomBytes(12).toString('base64url')}`;
}
