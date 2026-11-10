# SeatSure: manual test cases (final round)

Run in one sitting on the live deployment (https://seatsure-9hn0.onrender.com).
Devices: **P** = Android phone (release APK 1.0.1), **W** = laptop browser (web build),
**L** = Linux desktop build. Evidence: `ph-NN` = phone screenshot, `vid` = timestamp in a
recording, `lap-NN` = laptop screenshot.

Fill **Actual** and **Evidence** during the run. Pass = actual matches expected.

Before starting: `scripts/wake.sh` reports `db up`; phone on Do Not Disturb; phone screen
recorder and laptop recorder running.

## A. Accounts

| ID | Device | Steps | Expected | Actual | Evidence |
|---|---|---|---|---|---|
| A1 | P | Sign up with a new name, email, 8+ char password | Account created, lands on Rooms | Pass: account created, landed on Rooms | [221139](../evidence/2026-11-10-phone/screens/Screenshot_20261110_221139.jpg) |
| A2 | P | Log out, log in with a wrong password | "Wrong email or password" | | |
| A3 | P | Log in with the right password | Rooms screen; reopening the app stays logged in | | |
| A4 | P | Sign up again with the same email in other letter case | "An account with this email already exists" | | |
| A5 | P | Log out | Login screen, no grey screen or crash (regression for the logout bug) | | |

## B. Booking (student)

| ID | Device | Steps | Expected | Actual | Evidence |
|---|---|---|---|---|---|
| B1 | P | Open Rooms | Every room shows free seats right now | Pass: 24/10/12 free, hours shown | [221139](../evidence/2026-11-10-phone/screens/Screenshot_20261110_221139.jpg) |
| B2 | P | Open Central Reading Hall, pick the next slot (30 min) | Seat map: free / taken / yours in different colours | Pass: seat map with legend; A1 shown as yours after booking | [221404](../evidence/2026-11-10-phone/screens/Screenshot_20261110_221404.jpg) |
| B3 | P | Book a free seat | Success; booking in My bookings with a check-in countdown | Pass: "Booked A1. Check in now, before 10:15 PM"; booking in My bookings | [221335](../evidence/2026-11-10-phone/screens/Screenshot_20261110_221335.jpg) |
| B4 | W | Student 2 opens the same room and slot | Phone's seat shows as taken (within 15 s) | Pass: second student's A3 shows grey (Taken) on the phone | [Screenshot_20261110_225337.jpg](../evidence/2026-11-10-admin/screens/Screenshot_20261110_225337.jpg) |
| B5 | W | Student 2 tries to book that seat for an overlapping time | "That seat is already booked for part of this time" | | |
| B6 | P | Book a second seat overlapping your first booking | "You already have a booking that overlaps this time" | Pass: "You already have a booking that overlaps this time" | [221408](../evidence/2026-11-10-phone/screens/Screenshot_20261110_221408.jpg) |
| B7 | P | Hold 3 upcoming bookings, try a 4th | "You can hold at most 3 upcoming bookings; cancel one first" | | |
| B8 | P | Try more than 4 h, or a day beyond 7 days, or a time outside opening hours | Picker prevents it or a clear message (max 4 hours / 7 days ahead / room hours) | Pass (opening hours part): closed rooms say "closed for the rest of the day" | [221420](../evidence/2026-11-10-phone/screens/Screenshot_20261110_221420.jpg) |
| B9 | P+W | Both devices press Book on the same free seat at the same moment | Exactly one succeeds; the other gets the "already booked" message | | |
| B10 | P | Cancel an upcoming booking | Status Cancelled; seat free on W; cannot cancel it again | Pass: "Booking cancelled, seat released"; history shows Cancelled | [Screenshot_20261110_225357.jpg](../evidence/2026-11-10-admin/screens/Screenshot_20261110_225357.jpg) |

## C. QR check-in

| ID | Device | Steps | Expected | Actual | Evidence |
|---|---|---|---|---|---|
| C1 | P | Check in more than 10 min before start | "Too early: check-in for this seat opens at HH:MM" | Pass: "Too early: check-in for this seat opens at 11:05 pm" | [Screenshot_20261110_225914.jpg](../evidence/2026-11-10-admin/screens/Screenshot_20261110_225914.jpg) |
| C2 | P | Inside the window, scan **another** seat's QR with the camera | "Wrong seat: your booking is for seat X in Room" | Pass, phone camera: "Wrong seat: your booking is for seat A1 in Central Reading Hall" | [221310](../evidence/2026-11-10-phone/screens/Screenshot_20261110_221310.jpg) |
| C3 | P | Scan **your** seat's QR with the camera | Checked in; status Checked in; countdown gone | Pass, phone camera: "Checked in at A1"; status Checked in | [221346](../evidence/2026-11-10-phone/screens/Screenshot_20261110_221346.jpg) |
| C4 | P | Scan it again | "You are already checked in at this seat" | Pass: "You are already checked in at this seat" | [221457](../evidence/2026-11-10-phone/screens/Screenshot_20261110_221457.jpg) |
| C5 | P | Scan a QR that is not a SeatSure code (any other QR) | "This QR code is not a SeatSure seat" | Pass, phone camera: "This QR code is not a SeatSure seat" | [221320](../evidence/2026-11-10-phone/screens/Screenshot_20261110_221320.jpg) |
| C6 | P | Deny camera permission, then use the typed code under the QR | Camera-blocked hint; typed code checks in | | |
| C7 | P | Leave early on a checked-in booking | Status Completed; seat free on W at once | Pass: "Checked out. Thanks for freeing the seat!"; history shows Completed | [221507](../evidence/2026-11-10-phone/screens/Screenshot_20261110_221507.jpg) |
| C8 | P+W | Book a slot, do **not** check in, wait past start + 15 min | Booking becomes No-show; seat free for others; no timer needed | Pass: Riya's 22:45 booking, never checked in, became No-show at 23:00 with no timer | [laptop-admin-run.mp4](../evidence/2026-11-10-admin/laptop-admin-run.mp4) |

## D. Librarian (admin)

| ID | Device | Steps | Expected | Actual | Evidence |
|---|---|---|---|---|---|
| D1 | W | Student account opens an admin URL | Not allowed ("Admins only") | | |
| D2 | W | Admin dashboard before and after C3 | In use / waiting / free numbers change | Pass: dashboard went to 1 in use, 1 waiting, 44/46 free | [02-dashboard-live.jpg](../evidence/2026-11-10-admin/laptop/02-dashboard-live.jpg) |
| D3 | W | Day bookings list | Every booking of today with the student's name | Pass: today's list with every student's name and email | [01-bookings-today.jpg](../evidence/2026-11-10-admin/laptop/01-bookings-today.jpg) |
| D4 | W | Add a room and 4 seats | Room listed with 4 seats | | |
| D5 | W | Switch a room off, then on | Students cannot book it while off; description, floor and hours are unchanged afterwards (regression for the room-edit bug) | Pass: Silent Study Zone vanished for the student while off; floor, hours, description kept after on | [03-room-switched-off.jpg](../evidence/2026-11-10-admin/laptop/03-room-switched-off.jpg) |
| D6 | W | Disable a seat | Seat greyed out and not bookable on P | | |
| D7 | W | QR sheet: issue a new QR for a seat, scan the old printout | Old code: "not a SeatSure seat"; new code checks in | Pass: old A4 code "not a SeatSure seat"; new code recognised ("You have no booking for seat A4 right now") | [Screenshot_20261110_225744.jpg](../evidence/2026-11-10-admin/screens/Screenshot_20261110_225744.jpg) |

## E. Cross-platform and robustness

| ID | Device | Steps | Expected | Actual | Evidence |
|---|---|---|---|---|---|
| E1 | P+W+L | The same booking viewed on all three builds | Same data everywhere | Pass: the same bookings on the phone (Android) and the librarian's Linux desktop build | [01-bookings-today.jpg](../evidence/2026-11-10-admin/laptop/01-bookings-today.jpg) |
| E2 | P | Phone dark theme | App follows the system theme, everything readable | | |
| E3 | P | Airplane mode, then pull to refresh / book | Readable "cannot reach server" error, no crash | | |
| E4 | W | Server asleep (15 min idle), open the app | First request waits up to a minute, then works | | |
| E5 | W | Wide browser window, Check in tab | Code field visible (regression for the 1.0.1 layout fix) | | |

## Result

Two rounds on 10 Nov 2026, live server, real Android phone (release APK 1.0.1):

- 22:10-22:15, student side: 11 cases, 11 passed. Recording: [seatsure-phone-run.mp4](../evidence/2026-11-10-phone/seatsure-phone-run.mp4).
- 22:51-22:59, librarian on the Linux desktop build + student on the phone + a second student: 9 cases, 9 passed. Recordings: [laptop](../evidence/2026-11-10-admin/laptop-admin-run.mp4), [phone](../evidence/2026-11-10-admin/phone-run.mp4).

Passed: 20 / 20 run, no bugs. Not re-run on 10 Nov (covered in earlier rounds, report Section 11): A2-A5, B5, B7-B9, C6, D1, D4, D6, E2-E5. The faculty accepted the submission the same evening.
