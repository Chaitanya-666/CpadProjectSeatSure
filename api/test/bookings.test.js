import assert from 'node:assert/strict';
import { after, beforeEach, describe, it } from 'node:test';
import { api, istAt, makeRoom, makeUser, pool, query, resetDb } from './helpers.js';

beforeEach(resetDb);
after(() => pool.end());

const book = (user, seatId, start, end) =>
  api().post('/api/bookings').set(user.auth).send({ seatId, start, end });

describe('booking rules', () => {
  it('books a free seat', async () => {
    const u = await makeUser();
    const { seats } = await makeRoom();
    const res = await book(u, seats[0].id, istAt(1, '10:00'), istAt(1, '11:00'));
    assert.equal(res.status, 201);
    assert.equal(res.body.booking.status, 'booked');
    assert.equal(res.body.booking.seat.label, 'A1');
  });

  it('refuses an overlapping booking of the same seat (409 seat_taken)', async () => {
    const [a, b] = [await makeUser(), await makeUser()];
    const { seats } = await makeRoom();
    await book(a, seats[0].id, istAt(1, '10:00'), istAt(1, '11:00'));
    const res = await book(b, seats[0].id, istAt(1, '10:30'), istAt(1, '11:30'));
    assert.equal(res.status, 409);
    assert.equal(res.body.error.code, 'seat_taken');
  });

  it('allows back-to-back slots, because ranges are [start, end)', async () => {
    const [a, b] = [await makeUser(), await makeUser()];
    const { seats } = await makeRoom();
    await book(a, seats[0].id, istAt(1, '10:00'), istAt(1, '11:00'));
    const res = await book(b, seats[0].id, istAt(1, '11:00'), istAt(1, '12:00'));
    assert.equal(res.status, 201);
  });

  it('stops one student holding two seats at once (409 you_have_overlap)', async () => {
    const u = await makeUser();
    const { seats } = await makeRoom();
    await book(u, seats[0].id, istAt(1, '10:00'), istAt(1, '11:00'));
    const res = await book(u, seats[1].id, istAt(1, '10:30'), istAt(1, '11:30'));
    assert.equal(res.status, 409);
    assert.equal(res.body.error.code, 'you_have_overlap');
  });

  it('lets exactly one of two simultaneous requests for the same seat win', async () => {
    const [a, b] = [await makeUser(), await makeUser()];
    const { seats } = await makeRoom();
    const results = await Promise.all([
      book(a, seats[0].id, istAt(1, '15:00'), istAt(1, '16:00')),
      book(b, seats[0].id, istAt(1, '15:00'), istAt(1, '16:00')),
    ]);
    assert.deepEqual(results.map((r) => r.status).sort(), [201, 409]);
    const { rows } = await query(`SELECT count(*)::int AS n FROM bookings WHERE seat_id = $1`, [seats[0].id]);
    assert.equal(rows[0].n, 1);
  });

  it('enforces the per-student limit even for parallel requests', async () => {
    const u = await makeUser();
    const { seats } = await makeRoom({ seats: 5 });
    const hours = ['09:00', '11:00', '13:00', '15:00', '17:00'];
    const results = await Promise.all(
      hours.map((h, i) => book(u, seats[i].id, istAt(2, h), istAt(2, `${String(Number(h.slice(0, 2)) + 1)}:00`))),
    );
    const created = results.filter((r) => r.status === 201).length;
    assert.equal(created, 3);
    assert.ok(results.filter((r) => r.status === 409).every((r) => r.body.error.code === 'limit_reached'));
  });

  it('checks time rules: grid, length, past, horizon, opening hours', async () => {
    const u = await makeUser();
    const { seats } = await makeRoom();
    const { seats: dayRoomSeats } = await makeRoom({ open: '09:00', close: '18:00' });
    const cases = [
      [seats[0].id, istAt(1, '10:05'), istAt(1, '11:05'), /boundary/],
      [seats[0].id, istAt(1, '10:00'), istAt(1, '10:15'), /at least/],
      [seats[0].id, istAt(1, '08:00'), istAt(1, '13:00'), /at most/],
      [seats[0].id, istAt(-1, '10:00'), istAt(-1, '11:00'), /passed/],
      [seats[0].id, istAt(9, '10:00'), istAt(9, '11:00'), /days ahead/],
      [dayRoomSeats[0].id, istAt(1, '17:30'), istAt(1, '18:30'), /open 09:00/],
    ];
    for (const [seatId, start, end, pattern] of cases) {
      const res = await book(u, seatId, start, end);
      assert.equal(res.status, 400, `${start}–${end}`);
      assert.match(res.body.error.message, pattern);
    }
  });

  it('cancelling frees the seat; a booking cannot be cancelled twice or by someone else', async () => {
    const [a, b] = [await makeUser(), await makeUser()];
    const { seats } = await makeRoom();
    const first = await book(a, seats[0].id, istAt(1, '10:00'), istAt(1, '11:00'));
    const id = first.body.booking.id;

    assert.equal((await api().post(`/api/bookings/${id}/cancel`).set(b.auth)).status, 404);
    const cancelled = await api().post(`/api/bookings/${id}/cancel`).set(a.auth);
    assert.equal(cancelled.body.booking.status, 'cancelled');
    assert.equal((await api().post(`/api/bookings/${id}/cancel`).set(a.auth)).status, 409);
    assert.equal((await book(b, seats[0].id, istAt(1, '10:00'), istAt(1, '11:00'))).status, 201);
  });

  it('shows the seat map as free / taken / mine', async () => {
    const [a, b] = [await makeUser(), await makeUser()];
    const { room, seats } = await makeRoom();
    await book(a, seats[0].id, istAt(1, '10:00'), istAt(1, '11:00'));
    await book(b, seats[1].id, istAt(1, '10:00'), istAt(1, '11:00'));
    const res = await api()
      .get(`/api/rooms/${room.id}/availability`)
      .query({ start: istAt(1, '10:30'), end: istAt(1, '11:30') })
      .set(a.auth);
    assert.deepEqual(
      res.body.seats.map((s) => s.state),
      ['mine', 'taken', 'free'],
    );
  });

  it('lists my upcoming bookings only', async () => {
    const [a, b] = [await makeUser(), await makeUser()];
    const { seats } = await makeRoom();
    await book(a, seats[0].id, istAt(1, '10:00'), istAt(1, '11:00'));
    await book(b, seats[1].id, istAt(1, '10:00'), istAt(1, '11:00'));
    const res = await api().get('/api/bookings/me').set(a.auth);
    assert.equal(res.body.bookings.length, 1);
    assert.equal(res.body.bookings[0].seat.label, 'A1');
  });
});
