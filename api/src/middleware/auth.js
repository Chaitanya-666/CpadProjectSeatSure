import { query } from '../db.js';
import { forbidden, unauthorized } from '../lib/errors.js';
import { verifyToken } from '../lib/tokens.js';

// Reads "Authorization: Bearer <jwt>", checks the signature and expiry, then
// loads the user so a deleted account or changed role takes effect at once.
export async function requireAuth(req, _res, next) {
  const header = req.get('authorization') ?? '';
  const [scheme, token] = header.split(' ');
  if (scheme !== 'Bearer' || !token) throw unauthorized();

  let payload;
  try {
    payload = verifyToken(token);
  } catch {
    throw unauthorized('Session expired, please log in again');
  }
  const { rows } = await query('SELECT id, name, email, role FROM users WHERE id = $1', [Number(payload.sub)]);
  if (rows.length === 0) throw unauthorized('Account no longer exists');
  req.user = rows[0];
  next();
}

export function requireAdmin(req, _res, next) {
  if (req.user?.role !== 'admin') throw forbidden('Admins only');
  next();
}
