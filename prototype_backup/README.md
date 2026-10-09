# SkillPath Family Counselling Portal: UI prototype

Static front end (HTML, CSS, JS). No install, no build, no backend.

## Run
Open `index.html` in a browser, or upload the folder to Antigravity as a static site.
To serve locally: `python3 -m http.server 8000`, then open http://localhost:8000

## Demo logins
- Student / Parent: any 10-digit mobile number, OTP `123456`
- Administrator: choose the Administrator tab, OTP box = `admin123`

## Screens (top task bar, steps 1 to 7)
1. Login (OTP, language, consent) 2. Student profile 3. Family context + parent concerns
4. Counselling (concern buttons with verified data) 5. Recommendations 6. Pathway + vocational vs academic comparison
7. Family summary (printable) + human counsellor request. Admin dashboard is a separate tab for admin login.
The AI assistant sits at the bottom centre on every screen (tap to open, voice input in Chrome/Edge).

## Files
- `index.html`: all screens (one `<section data-page="...">` per screen)
- `style.css`: government-style theme (colours are CSS variables at the top)
- `app.js`: navigation, dummy data, bot. Places to connect a real backend are marked `BACKEND`.

## Connect later
Replace the dummy `TRADES` and `ADMIN_DEMO` data and the `BACKEND` functions (login, `computeRecs`, `botAsk`, `renderAdmin`)
with calls to your API (for example the FastAPI app from the first prototype).
The emblem is a placeholder "SP" logo; swap in your scheme's official branding where you are authorised to use it.
