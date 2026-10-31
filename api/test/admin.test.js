import assert from 'node:assert/strict';
import { after, beforeEach, describe, it } from 'node:test';
import { api, insertBooking, makeRoom, makeUser, pool, resetDb } from './helpers.js';

beforeEach(resetDb);
after(() => pool.end());

describe('admin', () => {
  it('is closed to students', async () => {
    const s = await makeUser();
    assert.equal((await api().get('/api/admin/stats').set(s.auth)).status, 403);
    assert.equal((await api().post('/api/admin/rooms').set(s.auth).send({ name: 'Hack' })).status, 403);
  });

  it('creates a room and adds seats in bulk', async () => {
    const admin = await makeUser({ role: 'admin' });
    const room = await api()
      .post('/api/admin/rooms')
      .set(admin.auth)
      .send({ name: 'Annex', openTime: '09:00', closeTime: '17:00' });
    assert.equal(room.status, 201);
    const seats = await api()
      .post(`/api/admin/rooms/${room.body.room.id}/seats`)
      .set(admin.auth)
      .send({ prefix: 'X', from: 1, count: 4, hasPower: true });
    assert.deepEqual(
      seats.body.seats.map((s) => s.label),
      ['X1', 'X2', 'X3', 'X4'],
    );
    const dup = await api()
      .post(`/api/admin/rooms/${room.body.room.id}/seats`)
      .set(admin.auth)
      .send({ labels: ['X5', 'X2'] });
    assert.equal(dup.status, 409);
    const list = await api().get(`/api/admin/rooms/${room.body.room.id}/seats`).set(admin.auth);
    assert.equal(list.body.seats.length, 4, 'the failed batch left nothing behind');
  });

  it('rejects closing before opening', async () => {
    const admin = await makeUser({ role: 'admin' });
    const res = await api()
      .post('/api/admin/rooms')
      .set(admin.auth)
      .send({ name: 'Backwards', openTime: '18:00', closeTime: '09:00' });
    assert.equal(res.status, 400);
  });

  it('rotating a QR code makes the old printed code useless', async () => {
    const admin = await makeUser({ role: 'admin' });
    const student = await makeUser();
    const { seats } = await makeRoom();
    await insertBooking({ seatId: seats[0].id, userId: student.id, startMinutesFromNow: -1 });
    const rotated = await api().post(`/api/admin/seats/${seats[0].id}/rotate-qr`).set(admin.auth);
    assert.notEqual(rotated.body.seat.qrToken, seats[0].qr_token);
    const old = await api().post('/api/checkin').set(student.auth).send({ qrToken: seats[0].qr_token });
    assert.equal(old.status, 404);
    const fresh = await api().post('/api/checkin').set(student.auth).send({ qrToken: rotated.body.seat.qrToken });
    assert.equal(fresh.status, 200);
  });

  it('reports stats and the day list with who booked', async () => {
    const admin = await makeUser({ role: 'admin' });
    const student = await makeUser({ name: 'Visible Name' });
    const { seats } = await makeRoom();
    await insertBooking({ seatId: seats[0].id, userId: student.id, startMinutesFromNow: -120, status: 'no_show' });
    await insertBooking({ seatId: seats[1].id, userId: student.id, startMinutesFromNow: -2 });

    const stats = await api().get('/api/admin/stats').set(admin.auth);
    assert.equal(stats.status, 200);
    assert.equal(stats.body.now.held, 1);
    assert.equal(stats.body.rooms[0].noShows, 1);

    const today = new Date(Date.now() + 5.5 * 3600 * 1000).toISOString().slice(0, 10);
    const day = await api().get('/api/admin/bookings').query({ date: today }).set(admin.auth);
    assert.ok(day.body.bookings.some((b) => b.user?.name === 'Visible Name'));
  });
});
