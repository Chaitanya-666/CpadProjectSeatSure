import { config } from './config.js';
import { createApp } from './app.js';
import { pool } from './db.js';

const server = createApp().listen(config.port, () => {
  console.log(`SeatSure API on http://localhost:${config.port} (${config.nodeEnv})`);
});

// Render sends SIGTERM on redeploy: finish open requests, then close the pool.
for (const signal of ['SIGTERM', 'SIGINT']) {
  process.on(signal, () => {
    server.close(() => pool.end().then(() => process.exit(0)));
  });
}
