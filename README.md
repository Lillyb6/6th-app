# Cloud Club

A playful mobile app for spotting shapes in clouds and comparing guesses with friends.

## Product flow

1. Take or upload a cloud photo.
2. Make your own guess about its shape.
3. Reveal an AI interpretation.
4. Share the photo so friends can guess, discuss, and vote.

## Repository

- `lib/`: Flutter home screen, spotting journal, and session collection; platform projects live at the repository root.
- `backend/`: Python API starter with a health endpoint.
- `docs/ROADMAP.md`: initial scope and development milestones.

## Start the backend

Requires Python 3.10 or newer. No third-party packages are needed yet.

```powershell
cd backend
python server.py
```

Visit `http://127.0.0.1:8000/health`. Expected response: `{"status": "ok", "service": "cloud-club-api"}`.

## Start the mobile app

Install the Flutter SDK and Android or iOS development prerequisites. From the repository root, run:

    flutter pub get
    flutter analyze
    flutter test
    flutter run

## Run tests

From the repository root:

```powershell
flutter test
flutter analyze
python -m unittest discover -s backend -p "test_*.py" -v
```

Flutter tests check the home screen, journal validation, save/delete/undo flow,
scrolling on a small phone, enlarged text, rotation to landscape, and device
safe areas. Backend tests start a temporary
local HTTP server on an available port and check health responses, query
parameters, unknown routes, JSON response headers, and continued availability
after invalid routes and unsupported HTTP methods. They require Python 3.10+
and use only the standard library; no running backend or API keys are needed.

## AI integration

Gemini image interpretation is planned. Calls will go through the Python backend, with credentials stored in server environment variables. Never place API keys in the mobile app or commit secrets.

## Baseline status

The app includes Home and Collection navigation. Record cloud shapes and optional notes, browse entries, and delete with Undo. Entries last for the current session and disappear when the app restarts. Photo capture, uploads, Gemini calls, accounts, persistent storage, and social features are not implemented. The app does not connect to the backend yet.
