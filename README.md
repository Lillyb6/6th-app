# Cloud Club

A playful mobile app for spotting shapes in clouds and comparing guesses with friends.

## Product flow

1. Take or upload a cloud photo.
2. Make your own guess about its shape.
3. Reveal an AI interpretation.
4. Share the photo so friends can guess, discuss, and vote.

## Repository

- `mobile/`: Flutter source scaffold and initial home screen.
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

Install the Flutter SDK with Android or iOS development prerequisites. The initial commit includes Dart source, but platform projects must be generated locally:

```powershell
cd mobile
flutter create --project-name cloud_club --platforms android,ios .
flutter pub get
flutter analyze
flutter run
```

If Flutter replaces `lib/main.dart` or `pubspec.yaml` during generation, restore the tracked Cloud Club versions before running the app. Review generated files before committing them.

## AI integration

Gemini image interpretation is planned. Calls will go through the Python backend, with credentials stored in server environment variables. Never place API keys in the mobile app or commit secrets.

## Baseline status

This is a starting scaffold. Photo capture, uploads, Gemini calls, accounts, storage, and social features are not implemented. The home screen does not connect to the backend yet.
