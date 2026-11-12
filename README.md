# Cloud Club

A photo community for people who always look up. Sign in, share a cloud, and collect your favourite views of the sky.

## The three tabs

- **Clouds:** a chronological, paginated feed of photos posted by members. Like photos, comment on clouds, copy a caption, and refresh for new posts.
- **Post (+):** choose a JPEG, PNG, or WebP photo up to 5 MB, preview it, ask Gemini for playful cloud-shape guesses, add a caption and optional location, then publish it to the club. You can feature it in your best clouds.
- **Profile:** a profile photo, name, editable bio, and galleries for best clouds and all your photos. Open a photo to feature or unfeature it, like it, or delete your own post.

Photos, captions, likes, bios, avatars, and best-cloud selections persist across app restarts. Accounts share the same community feed. The layout follows the cloud / plus / profile sketch on phones and uses a sidebar on desktop.

## Hosted backend (Supabase)

The Flutter app connects to the Supabase project configured in `lib/main.dart`. Supabase Auth handles accounts, Postgres stores profiles/posts/likes/comments, and the private `cloud-photos` Storage bucket holds uploaded images. Run `supabase/cloud_club.sql` in the project's SQL Editor before launching the app. Run it again when upgrading an existing project to create the comments table and access policies; the script is safe to rerun.

The project URL and publishable key can be overridden at build time:

Cloud shape guesses call the `cloud-shape` Edge Function. The function needs the
`GEMINI_API_KEY` secret configured in Supabase Edge Function secrets; the key
stays server-side. Tap **Guess this cloud** after choosing a photo. Alternative
guesses can be added to the caption.

```sh
flutter run -d chrome --web-hostname localhost --web-port 8080 \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_...
```

If email confirmation is enabled in Supabase Auth, new members must confirm their email before logging in. The old `backend/` Python/SQLite API remains available for local development and its tests, but the app entry point now uses Supabase. Existing SQLite accounts and posts are not automatically copied into Supabase.

## Build a web preview

```sh
flutter pub get
flutter run -d chrome --web-hostname localhost --web-port 8080
```

For a self-contained web build (including the Flutter rendering files):

```powershell
flutter build web --no-web-resources-cdn
python -m http.server 8080 --bind localhost --directory build/web
```

Open `http://localhost:8080`.

Windows desktop builds need Visual Studio's **Desktop development with C++** workload. Flutter file-picker plugins also require Windows Developer Mode for symbolic links. Chrome preview works without the native Windows build tools. macOS file-picker builds need the user-selected read-only file entitlement; it is included in both Runner entitlement files.

For an Android emulator:

```powershell
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

Physical devices need a reachable API address passed using `--dart-define=API_BASE_URL=...`. The backend binds to `127.0.0.1` by default. Set `HOST` only when you intentionally want to expose your development server to your local network. Web development allows the exact origin `http://localhost:8080`; set `WEB_ORIGIN` on the backend for a different web origin.

## Data and accounts

The backend saves to `backend/data/accounts.sqlite3`, ignored by Git. Set `AUTH_DATABASE` to change the path. Existing accounts are preserved, and the social tables are created automatically. Environment variables must be set in the shell; `.env` files are not loaded automatically.

Passwords use salted PBKDF2-HMAC-SHA256 hashes. Bearer sessions expire after 24 hours, and logout revokes them. Sessions stay in app memory, so restarting the app requires login again. Logging out clears the displayed account's data from the app; their saved photos remain in the database.

Uploads accept JPEG, PNG, and WebP signatures and enforce a 5 MB limit. Posts and avatars are stored as image data in the local database. The feed loads 12 photos at a time, with older photos available using **More clouds**. Profile galleries load older photos with **Load older clouds**. Counts describe the loaded photos; a plus indicates older photos remain.

API routes: `GET /feed`, `GET /profile`, `GET /profile/posts`, `POST /posts`, `POST /profile`, `POST /posts/{id}/like`, `POST /posts/{id}/best`, and `POST /posts/{id}/delete`. All require a valid login session. Feed and own-photo endpoints accept a `before` post-ID cursor. Only the owner can feature or delete a photo. Authentication routes remain `POST /auth/signup`, `POST /auth/login`, `POST /auth/logout`, and `GET /auth/me`.

This is a local development app. Hosted use still needs HTTPS, production hosting, image processing/storage, moderation/reporting, and operational limits. Photos are visible to signed-in members; there are no private posts. Comments, followers, photo capture, and password recovery are not included. The share action copies a caption rather than publishing an external link.

## Checks

```powershell
flutter analyze
flutter test
python -m unittest discover -s backend -p "test_*.py" -v
```

Flutter tests cover login, signup validation, logout, photo selection and posting, likes, best-cloud gallery, profile edits, errors, device safe areas, narrow phones, landscape, tablet, desktop, and enlarged text. Backend tests cover authentication, cross-account feed visibility, persistence, upload validation, idempotent likes, owner-only actions, deletion cleanup, and cursor pagination.

## Design and credits

The taste skill's **Editorial greeting** direction (seed `1131462837`) supplies Instrument Sans and Instrument Serif, flat pale-blue surfaces, rounded photographs, and quiet navigation. The sky photograph carries the colour; the app's controls stay restrained. The local preview includes six explicitly fictional members and cloud posts added with the optional demo-data script. Their sample likes are actual rows attached to the fictional accounts.

The welcome/empty-feed photograph is **Blue sky background clouds**, CC0, via [rawpixel](https://www.rawpixel.com/image/6039137/photo-image-background-cloud-public-domain). It is a welcome image, not a member's post. The feed displays its credit. Metadata is in `assets/credits.json`. Instrument Sans and Instrument Serif use the SIL Open Font License; the license texts are bundled in `assets/fonts/`.

The skill's HTML/CSS linter does not support Dart, and its DOM inspector cannot measure text drawn into Flutter's canvas. Responsive Flutter tests and actual browser screenshots provide the layout checks; the DOM-only report must not be presented as a clean audit.

## Optional social feed sample data

The current local database has six fictional cloud watchers with illustrated avatars, varied cloud photos, captions, and sample likes. These are demo posts, not real community activity.

To populate another local database, run `python backend/seed_demo.py`. Running it again does not duplicate posts. To remove only these fictional accounts and their posts, run `python backend/seed_demo.py --remove`. Both commands respect `AUTH_DATABASE` and preserve normal members and their posts. Demo accounts have no usable login credentials.

Cloud photographs are CC0 images credited in `assets/credits.json`. Avatars use Avataaars by Pablo Stanley, rendered through DiceBear, CC0; source details are in `backend/demo_assets/CREDITS.md`. All images are bundled locally, so the demo script and app do not fetch external avatar or photo services while running.
