# Shopping List - mobile app

The Android app of the Shopping List web app (see the [project README](../../README.md)). It signs in with the same account as the web, keeps the family's lists on the phone so it works **offline**, and syncs with the server through the [mobile API](../../docs/api.md).

## What it does

- **Sign in** with email and password; one token per device, kept in the Android keystore and revocable from the web or from **Settings > My devices**.
- **First login**: a person on a temporary password (the family name) gets a screen of their own, in the login's style, asking only for the **new password and its confirmation**. The app sends the temporary one it just used, so it is never asked for again.
- **Same rules as the web**: buttons appear only if the person holds the permission for that list type (add items, edit items, cart and purchase, manage lists), taken from the server's answer. Lists hidden from a person simply do not exist on their phone.
- **Same look as the web**: Tailwind's grays, white cards with soft shadows, Figtree font, blue/green/orange pill buttons, the sun/moon switch, the language menu, light and dark.
- **Same wording as the web**: the app reads the web app's own translation files (`assets/lang`), so texts are identical. After changing `resources/lang/*.json` at the project root, run `sh tool/sync_lang.sh`.
- **Offline first**: every edit is applied and stored on the phone at once, and sent with the next sync (soon after an edit, every 30 seconds, when the connection returns, when the app is reopened, or when you pull down / tap the banner). A strip under the top bar says when the phone is offline or changes are waiting.
- **Conflicts**: per field, last write wins (two phones changing different fields of the same item keep both). What the server refuses (no permission, the list is gone) is undone and explained.
- **Footer and account menu links** come from the backoffice (Menus), in the app's language, and are kept for offline use. Pages open in the browser.
- **Export** a list as a markdown checklist to any app, **finish** a list, create/edit lists and choose who a list is hidden from.

Not in the app yet (done on the web): managing family members, list types and permissions. Phone-to-phone sync is planned.

## Running it

Requirements: Flutter 3.47+, the Android SDK with its licences accepted (`flutter doctor --android-licenses`), a phone with USB debugging (or an emulator).

The server address defaults to `http://localhost:8000`, which is what you want with the phone on USB:

```bash
php artisan db:seed --class=DemoSeeder         # in the project root: a demo family (see the root README)
php artisan serve --port=8000                  # the web app and the API
adb reverse tcp:8000 tcp:8000                  # the phone's localhost:8000 is this PC's

cd mobile/shopping_list
flutter pub get
flutter run                                    # or: flutter build apk --debug, then adb install -r
```

Sign in with `joana@demo.test` and the password `Silva` (the family name; the app asks for a new one). Other demo people: `bia@demo.test`, `rui@demo.test` (see the root README for what each may do).

To point a build at another server: `flutter run --dart-define=API_BASE_URL=https://lists.example.com`, or type the address under **Server** on the sign-in screen.

Plain `http` is only allowed for `localhost` and `10.0.2.2` (see `android/app/src/main/res/xml/network_security_config.xml`); any other server must use HTTPS.

```bash
flutter analyze        # static analysis
flutter test           # the sync, permissions and API client tests
```

## How it is built

```
lib/
  core/        time and JSON helpers
  data/        api_client (the /api/v1 client), local_db (SQLite), repository (edits, outbox, merge), models, me (permissions)
  state/       settings (language, theme, texts), auth (token, first login), sync (when and how), menu_service (footer links)
  ui/          theme (the web's look), widgets, screens
```

The heart is `Repository`: edits mark the fields changed on the phone (`pending`, with the time of each change); `buildPush` turns them into the request; `applyResponse` merges the answer field by field, drops lists that are no longer visible, undoes refused changes and stores the cursor. It is covered by unit tests with an in-memory store (`test/`).
