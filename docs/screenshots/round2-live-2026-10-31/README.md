# Test round 2: live deployment (2026-10-31, ~3:45–4:00 PM IST)

Live site https://seatsure-9hn0.onrender.com (Render, Singapore) + Neon
Postgres (Singapore). Tested by Chaitanya in Brave on the laptop, dark theme.

1. `01_BUG_…`: on a 1920 px wide window the Check in screen's square camera
   box filled the width (~1700 px tall) and pushed the "type the code" field
   off-screen; Brave had also blocked the camera. Fixed in app 1.0.1
   (check-in column limited to 480 px, clearer camera-blocked hint).
2. `02_…`: own student account booked D1 (Digital Library Lab) 3:45–4:45 PM;
   card says "Check in now! … within 9 min".
3. `03_…`: seat map, D1 shown as "Yours".
4. `04_…`: admin dashboard (left window) and the student's booking checked in
   at 3:54 PM (right window), side by side.
5. `05_…`: admin QR sheet in dark mode; codes sit on white so they still scan.

The Profile screenshot is not stored here because it shows a personal email
(this repo is public).
