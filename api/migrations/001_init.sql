-- SeatSure schema, version 1.
-- Rule of thumb: anything that must never be wrong (no double booking,
-- valid statuses, valid times) is enforced here in the database, not only
-- in the API, so it still holds when two requests race each other.

-- btree_gist lets one GiST index mix "=" on an integer column with "&&"
-- (overlaps) on a time range. The exclusion constraints below need it.
CREATE EXTENSION IF NOT EXISTS btree_gist;

CREATE TABLE users (
  id            serial PRIMARY KEY,
  name          text        NOT NULL CHECK (length(trim(name)) BETWEEN 2 AND 80),
  email         text        NOT NULL,
  password_hash text        NOT NULL,
  role          text        NOT NULL DEFAULT 'student'
                            CHECK (role IN ('student', 'admin')),
  created_at    timestamptz NOT NULL DEFAULT now()
);
-- Case-insensitive unique email: "A@x.com" and "a@x.com" are the same user.
CREATE UNIQUE INDEX users_email_unique ON users (lower(email));

-- A room is a reading hall or zone in the library, with opening hours
-- (local time, see APP_TIMEZONE in the API).
CREATE TABLE rooms (
  id          serial PRIMARY KEY,
  name        text    NOT NULL UNIQUE CHECK (length(trim(name)) BETWEEN 2 AND 80),
  description text    NOT NULL DEFAULT '',
  floor       text    NOT NULL DEFAULT '',
  open_time   time    NOT NULL DEFAULT '08:00',
  close_time  time    NOT NULL DEFAULT '22:00',
  is_active   boolean NOT NULL DEFAULT true,
  CHECK (open_time < close_time)
);

-- Each seat has a random qr_token printed as a QR code on the desk.
-- Scanning it proves the student is physically at that seat.
CREATE TABLE seats (
  id         serial PRIMARY KEY,
  room_id    integer NOT NULL REFERENCES rooms (id) ON DELETE CASCADE,
  label      text    NOT NULL CHECK (length(trim(label)) BETWEEN 1 AND 10),
  has_power  boolean NOT NULL DEFAULT false,
  qr_token   text    NOT NULL UNIQUE,
  is_active  boolean NOT NULL DEFAULT true,
  UNIQUE (room_id, label)
);
CREATE INDEX seats_room_idx ON seats (room_id);

-- A booking holds one seat for one time range [start, end).
-- status:
--   booked      waiting for check-in
--   checked_in  student scanned the seat QR in time
--   completed   student checked out early (slot was cut short to that moment)
--   cancelled   student cancelled before the slot
--   no_show     not checked in within the grace period, seat released
CREATE TABLE bookings (
  id            serial PRIMARY KEY,
  seat_id       integer     NOT NULL REFERENCES seats (id) ON DELETE CASCADE,
  user_id       integer     NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  slot          tstzrange   NOT NULL,
  status        text        NOT NULL DEFAULT 'booked'
                            CHECK (status IN ('booked', 'checked_in', 'completed', 'cancelled', 'no_show')),
  checked_in_at timestamptz,
  ended_at      timestamptz,
  created_at    timestamptz NOT NULL DEFAULT now(),
  -- Slot must be a proper [start, end) range with a real start and end.
  CHECK (NOT isempty(slot) AND NOT lower_inf(slot) AND NOT upper_inf(slot)),
  CHECK (lower_inc(slot) AND NOT upper_inc(slot)),
  -- checked_in_at is set exactly when the student checked in at some point.
  CHECK ((status IN ('checked_in', 'completed')) = (checked_in_at IS NOT NULL)),

  -- No double booking: two live bookings for the same seat may not overlap.
  -- Cancelled / no-show / completed rows drop out of the WHERE, which is how
  -- releasing a seat makes it bookable again.
  CONSTRAINT no_seat_overlap EXCLUDE USING gist (seat_id WITH =, slot WITH &&)
    WHERE (status IN ('booked', 'checked_in')),

  -- One student cannot hold two seats at the same time.
  CONSTRAINT no_user_overlap EXCLUDE USING gist (user_id WITH =, slot WITH &&)
    WHERE (status IN ('booked', 'checked_in'))
);
CREATE INDEX bookings_user_idx ON bookings (user_id, lower(slot));
-- Partial index for the no-show sweep: it only ever looks at 'booked' rows.
CREATE INDEX bookings_pending_idx ON bookings (lower(slot)) WHERE status = 'booked';
