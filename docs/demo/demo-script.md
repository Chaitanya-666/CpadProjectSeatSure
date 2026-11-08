# SeatSure: demo script (6–7 minutes)

Used for the ESE demo and as the shot list for the backup video.

## 20 minutes before

1. `scripts/wake.sh` until it prints `UP ... db up`. If it gives up: Render dashboard,
   Manual Deploy > Deploy latest commit (about 4 minutes).
2. Optional: fresh history with `npm run seed -- --bookings` (keeps users, rooms, QR codes).
3. Laptop: browser logged in as admin on the dashboard; QR sheet of Central Reading Hall
   in a second tab. Phone: app open, logged in as a student, Do Not Disturb on.
4. If the backup video is needed: `docs/demo/` has the link and the file.

## The demo

| Time | Show | Say (one line each) |
|---|---|---|
| 0:00 | Title + problem | "Library seats get hoarded: people book and never come. SeatSure books seats by time slot, checks you in with a QR code at the desk, and frees the seat if you don't show up." |
| 0:30 | Stack slide or README diagram | "One Flutter codebase for Android, web and Linux desktop; a Node + Express REST API; PostgreSQL. Hosted on Render and Neon." |
| 1:00 | Phone: Rooms, seat map | "Free, taken and mine. The map refreshes every 15 seconds." |
| 1:30 | Phone: book a seat | Book the next slot. "The rules are checked on the server: 15-minute grid, 30 min to 4 h, 7 days ahead, opening hours." |
| 2:00 | Laptop as student 2: same seat | "Already booked for part of this time. The database refuses the overlap with an exclusion constraint, so even two taps at the same instant cannot double book." |
| 2:45 | Phone: scan the wrong seat, then the right seat | "Wrong seat tells you where your booking is. The right QR checks you in." |
| 3:30 | Laptop admin dashboard | "In use went up by one, live." Show day bookings with names. |
| 4:00 | A no-show booking in history | "Nobody checked in within 15 minutes, so it was released. There's no timer: expiry is computed when data is read, which works even though the free server sleeps." |
| 4:45 | Admin: rooms, switch a room off/on, QR sheet, new QR | "The old printed code stops working at once." |
| 5:30 | Linux desktop app | "Same code, desktop build, same data." |
| 6:00 | Tests + CI | "37 automated tests run on every push, including two parallel requests for one seat and a regression test for every bug we found." |
| 6:30 | Close | "Known limits: polling instead of push, static QR codes. Happy to show any part of the code." |

## If something goes wrong

- Server does not answer: say "free tier is waking up", show the backup video meanwhile.
- Camera will not focus on the screen: use the typed code under the QR (same API call).
- Phone has no internet: run the demo from the web build on the laptop.
