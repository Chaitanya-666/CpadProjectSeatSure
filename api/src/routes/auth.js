import { Router } from 'express';
import rateLimit from 'express-rate-limit';
import { z } from 'zod';
import { config } from '../config.js';
import { query } from '../db.js';
import { unauthorized } from '../lib/errors.js';
import { hashPassword, verifyPassword } from '../lib/password.js';
import { signToken } from '../lib/tokens.js';
import { requireAuth } from '../middleware/auth.js';

export const authRouter = Router();

// Slow down password guessing: 20 attempts per 15 minutes per IP.
const loginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: config.nodeEnv === 'test' ? 1000 : 20,
  standardHeaders: 'draft-8',
  legacyHeaders: false,
  message: { error: { code: 'rate_limited', message: 'Too many attempts, try again in a few minutes' } },
});

const email = z.string().trim().toLowerCase().pipe(z.email('Enter a valid email'));

const registerBody = z.object({
  name: z.string().trim().min(2, 'Name is too short').max(80, 'Name is too long'),
  email,
  password: z.string().min(8, 'Password must be at least 8 characters').max(100),
});

const loginBody = z.object({
  email,
  password: z.string().min(1, 'Enter your password'),
});

const publicUser = ({ id, name, email, role }) => ({ id, name, email, role });

// Self sign-up always creates a student. Admins are created by the seed
// script (or promoted in the database), never through the public API.
authRouter.post('/register', loginLimiter, async (req, res) => {
  const body = registerBody.parse(req.body);
  const { rows } = await query(
    `INSERT INTO users (name, email, password_hash)
     VALUES ($1, $2, $3)
     RETURNING id, name, email, role`,
    [body.name, body.email, await hashPassword(body.password)],
  );
  const user = rows[0];
  res.status(201).json({ token: signToken(user), user: publicUser(user) });
});

authRouter.post('/login', loginLimiter, async (req, res) => {
  const body = loginBody.parse(req.body);
  const { rows } = await query('SELECT * FROM users WHERE lower(email) = $1', [body.email]);
  const user = rows[0];
  // Same message for "no such email" and "wrong password", so the API does
  // not reveal which emails have accounts.
  if (!user || !(await verifyPassword(body.password, user.password_hash))) {
    throw unauthorized('Wrong email or password');
  }
  res.json({ token: signToken(user), user: publicUser(user) });
});

authRouter.get('/me', requireAuth, (req, res) => {
  res.json({ user: publicUser(req.user) });
});
