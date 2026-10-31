# Test round 1 (2026-10-31)

Android: emulator `labpixel` (Pixel, API 36), release APK built with
`API_BASE_URL=http://10.0.2.2:3000`, API + Postgres on the laptop.
Web: same API serving the Flutter web build, headless Chromium 1280x800.

Flow: Chaitanya logs in on Android, books A3 in Central Reading Hall for
2:45–3:45 PM, checks in with the code under the QR. Riya, on the web build,
then sees A3 as taken: one database, two platforms.

`10_BUG_grey_screen_after_logout.png`: logging out crashed the release build
(null check on the user while the old screens rebuilt). Fixed in commit
"App: fix crash on logout…" with a regression test; the admin shots
(11–14) are after the fix.
