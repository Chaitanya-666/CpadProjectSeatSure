import assert from 'node:assert/strict';
import { after, beforeEach, describe, it } from 'node:test';
import { api, makeUser, pool, resetDb } from './helpers.js';

beforeEach(resetDb);
after(() => pool.end());

describe('auth', () => {
  it('registers a student and returns a token', async () => {
    const res = await api()
      .post('/api/auth/register')
      .send({ name: 'Asha Rao', email: 'Asha@Example.com', password: 'longenough' });
    assert.equal(res.status, 201);
    assert.ok(res.body.token);
    assert.deepEqual(
      { email: res.body.user.email, role: res.body.user.role },
      { email: 'asha@example.com', role: 'student' },
    );
  });

  it('ignores a role sent by the client (no self-made admins)', async () => {
    const res = await api()
      .post('/api/auth/register')
      .send({ name: 'Sneaky', email: 'sneaky@x.com', password: 'longenough', role: 'admin' });
    assert.equal(res.body.user.role, 'student');
  });

  it('treats emails case-insensitively for uniqueness', async () => {
    await api().post('/api/auth/register').send({ name: 'One', email: 'dup@x.com', password: 'longenough' });
    const res = await api().post('/api/auth/register').send({ name: 'Two', email: 'DUP@x.com', password: 'longenough' });
    assert.equal(res.status, 409);
    assert.equal(res.body.error.code, 'email_taken');
  });

  it('rejects bad input with a readable message', async () => {
    const res = await api().post('/api/auth/register').send({ name: 'X', email: 'nope', password: 'short' });
    assert.equal(res.status, 400);
    assert.equal(res.body.error.code, 'validation');
    assert.ok(res.body.error.details.length >= 2);
  });

  it('logs in with the right password only, same error for unknown email', async () => {
    await api().post('/api/auth/register').send({ name: 'Login Me', email: 'me@x.com', password: 'rightpass' });
    const ok = await api().post('/api/auth/login').send({ email: 'ME@x.com', password: 'rightpass' });
    assert.equal(ok.status, 200);
    const wrong = await api().post('/api/auth/login').send({ email: 'me@x.com', password: 'wrongpass' });
    const unknown = await api().post('/api/auth/login').send({ email: 'ghost@x.com', password: 'whatever1' });
    assert.equal(wrong.status, 401);
    assert.equal(unknown.status, 401);
    assert.equal(wrong.body.error.message, unknown.body.error.message);
  });

  it('protects routes: no token, bad token, valid token', async () => {
    assert.equal((await api().get('/api/auth/me')).status, 401);
    assert.equal((await api().get('/api/auth/me').set('Authorization', 'Bearer not.a.jwt')).status, 401);
    const u = await makeUser();
    const me = await api().get('/api/auth/me').set(u.auth);
    assert.equal(me.status, 200);
    assert.equal(me.body.user.id, u.id);
  });

  it('reports health with the database up', async () => {
    const res = await api().get('/api/health');
    assert.equal(res.status, 200);
    assert.equal(res.body.db, 'up');
  });
});
