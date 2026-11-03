# Cloud Club

A playful mobile app for spotting shapes in clouds and comparing guesses with friends.

## Product flow

1. Create an account or log in.
2. Record a cloud shape and an optional note in the session journal.
3. Browse your collection or delete an entry with Undo.

Photo capture, AI interpretations, and sharing with friends are planned next.

## Repository

- `lib/`: Flutter home screen, spotting journal, and session collection; platform projects live at the repository root.
- `backend/`: Python API with SQLite accounts, login sessions, and health endpoint.
- `docs/ROADMAP.md`: initial scope and development milestones.

## Start the backend

Requires Python 3.10 or newer. No third-party packages are needed yet.

```powershell
cd backend
python server.py
```

Visit `http://127.0.0.1:8000/health`. Expected response: `{"status": "ok", "service": "cloud-club-api"}`.

Leave the backend running while using signup and login. Accounts are saved to
`backend/data/accounts.sqlite3` (ignored by Git). Set `AUTH_DATABASE` to change
the database path. Environment variables must be set in the shell; `.env` files
are examples and are not loaded automatically.

## Start the mobile app

Install the Flutter SDK and Android or iOS development prerequisites. From the repository root, run:

    flutter pub get
    flutter analyze
    flutter test
    flutter run

The default API address is `http://127.0.0.1:8000`, suitable for the Windows app
or a browser on the backend computer. For the Android emulator, use:

```powershell
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

For local Flutter web development, the backend allows the exact origin
`http://localhost:8080` by default:

```powershell
flutter run -d chrome --web-hostname localhost --web-port 8080
```

Set `WEB_ORIGIN` on the backend if the web app uses a different origin.
Physical devices need a reachable backend address supplied with
`--dart-define=API_BASE_URL=...`. Hosted builds should use an HTTPS backend;
Android permits local HTTP only in debug builds. The bundled Python HTTP server
is for local development, not a public production deployment.

## Accounts and login

The app requires login before showing the journal. Signup asks for a name,
email, a password of 12–128 characters, and password confirmation. Email
addresses are normalized to lowercase. The server stores unique salted
PBKDF2-HMAC-SHA256 password hashes with 600,000 iterations, not plaintext
passwords. Random bearer sessions expire after 24 hours; logout revokes the
session on the server. Authentication requests are limited to 10 per minute
per client IP in this single-server setup.

Session tokens are held only in app memory, so restarting requires login again.
Accounts survive backend restarts. Journal entries remain session-only and are
cleared on logout, expiry, or app restart; they are not saved with the account
yet. Email verification, password reset, and account deletion are not implemented.

API routes: `POST /auth/signup`, `POST /auth/login`, `POST /auth/logout`, and
`GET /auth/me`. The last two require `Authorization: Bearer <token>`.

## Run tests

From the repository root:

```powershell
flutter test
flutter analyze
python -m unittest discover -s backend -p "test_*.py" -v
```

Flutter tests check required login, signup confirmation, rejected credentials,
network errors, logout isolation, journal validation, save/delete/undo flow,
scrolling on a small phone, enlarged text, rotation to landscape, and device
safe areas. Backend tests start a temporary
local HTTP server on an available port and check health responses, query
parameters, unknown routes, JSON response headers, and continued availability
after invalid routes and unsupported HTTP methods. Authentication tests also
check persistent accounts, password hashing, expired and revoked sessions,
duplicate emails, validation, and rate limiting. They require Python 3.10+
and use only the standard library; no running backend or API keys are needed.

## AI integration

Gemini image interpretation is planned. Calls will go through the Python backend, with credentials stored in server environment variables. Never place API keys in the mobile app or commit secrets.

## Baseline status

The app includes required signup/login, logout, and Home and Collection navigation. Record cloud shapes and optional notes, browse entries, and delete with Undo. Accounts persist on the backend; journal entries disappear on logout or restart. Photo capture, uploads, Gemini calls, persistent journal storage, and social features are not implemented.
