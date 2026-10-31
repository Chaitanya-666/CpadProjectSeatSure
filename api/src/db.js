import pg from 'pg';
import { config } from './config.js';

// One pool for the whole process. Each request borrows a connection and
// gives it back; this is far cheaper than opening a new connection per query.
export const pool = new pg.Pool({
  connectionString: config.databaseUrl,
  ...(config.databaseSsl === undefined ? {} : { ssl: config.databaseSsl ? { rejectUnauthorized: true } : false }),
  max: 10,
});

export function query(text, params) {
  return pool.query(text, params);
}

// Run fn inside BEGIN ... COMMIT on a single connection. Any error rolls the
// whole thing back, so a half-finished change is never left in the database.
export async function withTransaction(fn) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const result = await fn(client);
    await client.query('COMMIT');
    return result;
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}
