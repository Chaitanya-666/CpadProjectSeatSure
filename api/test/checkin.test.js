import assert from 'node:assert/strict';
import { after, beforeEach, describe, it } from 'node:test';
import { api, insertBooking, istAt, makeRoom, makeUser, pool, query, resetDb } from './helpers.js';

beforeEach(resetDb);
after(() => pool.end());

const checkin = (user, qrToken) => api().post('/api/checkin').set(user.auth).send({ qrToken });

describe('QR check-in and no-show release', () => {
  it('checks in when the right seat is scanned inside the window', async () => {
    const u = await makeUser();
    const { seats } = await makeRoom();
    await insertBooking({ seatId: seats[0].id, userId: u.id, startMinutesFromNow: -5 });
    const res = await checkin(u, seats[0].qr_token);
    assert.equal(res.status, 200);
    assert.equal(res.body.booking.status, 'checked_in');
    assert.ok(res.body.booking.checkedInAt);
    assert.equal((await checkin(u, seats[0].qr_token)).body.error.code, 'already_checked_in');
  });

  it('allows checking in a few minutes early', async () => {
    const u = await makeUser();
    const { seats } = await makeRoom();
    await insertBooking({ seatId: seats[0].id, userId: u.id, startMinutesFromNow: 5 });
    assert.equal((await checkin(u, seats[0].qr_token)).status, 200);
  });

  it('says too early, wrong seat, unknown code, or no booking', async () => {
    const u = await makeUser();
    const { seats } = await makeRoom();
    await insertBooking({ seatId: seats[0].id, userId: u.id, startMinutesFromNow: 60 });
    assert.equal((await checkin(u, seats[0].qr_token)).body.error.code, 'too_early');

    const v = await makeUser();
    await insertBooking({ seatId: seats[1].id, userId: v.id, startMinutesFromNow: -2 });
    const wrong = await checkin(v, seats[2].qr_token);
    assert.equal(wrong.body.error.code, 'wrong_seat');
    assert.match(wrong.body.error.message, /A2/);

    assert.equal((await checkin(v, 'seat_made_up')).status, 404);
    const w = await makeUser();
    assert.equal((await checkin(w, seats[0].qr_token)).body.error.code, 'no_booking');
  });

  it('releases a no-show lazily: the seat is free on the next request, no timer needed', async () => {
    const [late, other] = [await makeUser(), await makeUser()];
    const { room, seats } = await makeRoom();
    // Started 20 minutes ago, grace is 15, never checked in.
    const b = await insertBooking({ seatId: seats[0].id, userId: late.id, startMinutesFromNow: -20, minutes: 90 });
    assert.equal((await query('SELECT status FROM bookings WHERE id = $1', [b.id])).rows[0].status, 'booked');

    // Any booking-related request runs the sweep first.
    const list = await api().get('/api/rooms').set(other.auth);
    assert.equal(list.body.rooms.find((r) => r.id === room.id).freeNow, 3);
    assert.equal((await query('SELECT status FROM bookings WHERE id = $1', [b.id])).rows[0].status, 'no_show');

    assert.equal((await checkin(late, seats[0].qr_token)).body.error.code, 'checkin_closed');
    const grab = await api()
      .post('/api/bookings')
      .set(other.auth)
      .send({ seatId: seats[0].id, start: istAt(1, '10:00'), end: istAt(1, '11:00') });
    assert.equal(grab.status, 201);
  });

  it('checking out early marks the booking completed and frees the seat now', async () => {
    const u = await makeUser();
    const { room, seats } = await makeRoom();
    await insertBooking({ seatId: seats[0].id, userId: u.id, startMinutesFromNow: -5, minutes: 120 });
    const { body } = await checkin(u, seats[0].qr_token);
    const before = await api().get('/api/rooms').set(u.auth);
    assert.equal(before.body.rooms.find((r) => r.id === room.id).freeNow, 2);

    const out = await api().post(`/api/bookings/${body.booking.id}/checkout`).set(u.auth);
    assert.equal(out.body.booking.status, 'completed');
    assert.ok(out.body.booking.endedAt);
    const afterRes = await api().get('/api/rooms').set(u.auth);
    assert.equal(afterRes.body.rooms.find((r) => r.id === room.id).freeNow, 3);
  });
});
