import { existsSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import cors from 'cors';
import express from 'express';
import helmet from 'helmet';
import { config } from './config.js';
import { query } from './db.js';
import { errorHandler, notFoundHandler } from './middleware/errorHandler.js';
import { adminRouter } from './routes/admin.js';
import { authRouter } from './routes/auth.js';
import { bookingsRouter } from './routes/bookings.js';
import { checkinRouter } from './routes/checkin.js';
import { roomsRouter } from './routes/rooms.js';

const pkg = JSON.parse(
  await import('node:fs/promises').then((fs) => fs.readFile(new URL('../package.json', import.meta.url), 'utf8')),
);

export function createApp() {
  const app = express();
  app.set('trust proxy', 1); // Render puts one proxy in front; needed for the rate limiter's IP
  // CSP off: the Flutter web build loads its own scripts and wasm.
  app.use(helmet({ contentSecurityPolicy: false, crossOriginEmbedderPolicy: false }));
  // The app sends a Bearer token, not cookies, so any origin may call the API.
  app.use(cors());
  app.use(express.json({ limit: '20kb' }));

  const api = express.Router();

  // Open this first in a demo: proves the server is up and the DB answers.
  api.get('/health', async (_req, res) => {
    try {
      const { rows } = await query('SELECT now() AS db_time');
      res.json({ status: 'ok', db: 'up', version: pkg.version, dbTime: rows[0].db_time, timezone: config.timezone });
    } catch {
      res.status(503).json({ status: 'degraded', db: 'down', version: pkg.version });
    }
  });

  // Booking rules, so the app builds its pickers from the same numbers.
  api.get('/config', (_req, res) => {
    res.json({ timezone: config.timezone, ...config.booking });
  });

  api.use('/auth', authRouter);
  api.use('/rooms', roomsRouter);
  api.use('/bookings', bookingsRouter);
  api.use('/checkin', checkinRouter);
  api.use('/admin', adminRouter);
  api.use(notFoundHandler);

  app.use('/api', api);

  // Serve the Flutter web build from the same server when it is present.
  const webDir = process.env.WEB_DIR ?? path.join(path.dirname(fileURLToPath(import.meta.url)), '..', 'public');
  if (existsSync(path.join(webDir, 'index.html'))) {
    app.use(express.static(webDir, { index: 'index.html', maxAge: '1h' }));
    app.get('/{*splat}', (_req, res) => res.sendFile(path.join(webDir, 'index.html')));
  } else {
    app.get('/', (_req, res) => res.json({ name: 'SeatSure API', docs: '/api/health' }));
  }

  app.use(errorHandler);
  return app;
}
