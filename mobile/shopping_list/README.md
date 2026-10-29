# Family Shopper - mobile app

The Android app of the Family Shopper web app (see the [project README](../../README.md)). It signs in with the same account as the web, keeps the family's lists on the phone so it works **offline**, and syncs with the server through the [mobile API](../../docs/api.md).

## What it does

- **Sign in** with email and password; one token per device, kept in the Android keystore and revocable from the web or from **Settings > My devices**.
- **First login**: a person on a temporary password (the family name) gets a screen of their own, in the login's style, asking only for the **new password and its confirmation**. The app sends the temporary one it just used, so it is never asked for again.
- **Same rules as the web**: buttons appear only if the person holds the permission for that list type (add items, edit items, cart and purchase, manage lists), taken from the server's answer. Lists hidden from a person simply do not exist on their phone.
- **Same look as the web**: Tailwind's grays, white cards with soft shadows, Figtree font, blue/green/orange pill buttons, the sun/moon switch, the language menu, light and dark.
- **A local database of everything**: besides the family's lists, the phone stores the **languages, every text, the content pages (About, Privacy, Terms...) and the menu links** with who each is for, from `GET /api/v1/content`. A fresh install starts from the copy shipped in `assets/content.json`, so even the first launch works offline; the app asks for what changed on start, on resume, on sign-in/out and on pull-to-refresh. Edit a text, page or link in the backoffice and the phones pick it up. After changing them (or `resources/lang/*.json`) on a freshly seeded database, run `sh tool/sync_lang.sh` to refresh the shipped copy.
- **Offline first**: every edit is applied and stored on the phone at once, and sent with the next sync (soon after an edit, every 30 seconds, when the connection returns, when the app is reopened, or when you pull down / tap the banner). A strip under the top bar says when the phone is offline or changes are waiting.
- **Conflicts**: per field, last write wins (two phones changing different fields of the same item keep both). What the server refuses (no permission, the list is gone) is undone and explained.
- **Footer and account menu links** come from the backoffice (Menus), in the app's language, and are kept in that database. A page opens **inside the app** from the local copy; only a link to an outside address opens the browser.
- **Export** a list as a markdown checklist to any app, **finish** a list, create/edit lists and choose who a list is hidden from.

- **Family** (family admins only, a third tab): members with their role and first-login status, add/edit with a permission chip per ability and list type, reset a password (the temporary password is shown with a Copy button), remove, and the family's list types. These need a connection; the rules (last admin, a type in use...) are the server's, and its messages come back in the app's language.

- **Notifications** about what others did (an item added, put in the cart or bought, a new list): with the app in use nothing is shown (you see it arrive); in the background the phone asks the server every ~15 minutes (Android's shortest interval for scheduled work, so a notification may come up to that late) and a tap opens the list. Never about your own changes, nor about lists you may not see. On/off in Settings; Android 13+ asks for permission at the first sign-in. There is no Firebase behind it. On Samsung phones, take the app out of "sleeping apps" so the schedule is not stopped.
- **Nearby sync**: with no way to the server, the app looks for the nearest phone of the same family running **exactly the same version** (Settings shows it) and swaps what neither has sent yet, over Bluetooth/Wi-Fi with no internet. Phones prove who they are with credentials the server signed, so nobody can see a list hidden from them or do what they may not. When any phone reaches the server again, the ordinary sync sends everything and brings back what changed on the web or on other phones. Only while the app is open and offline. See "Nearby sync" in [docs/api.md](../../docs/api.md).

Not in the app yet: nothing planned.

## Name and icon

The app is called **Family Shopper** (Android id `app.familyshopper.mobile`). The icon is a basket with a tick; its sources are SVGs in `assets/icon`. To change it: edit them, then `node assets/icon/render.mjs` (needs Chrome; also refreshes the web app's favicon and logos) and `dart run flutter_launcher_icons`.

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

Plain `http` is only allowed for `localhost` and `10.0.2.2` in **release** builds (see `android/app/src/main/res/xml/network_security_config.xml`); any other server must use HTTPS. **Debug** builds may use plain `http` to any address (`android/app/src/debug/res/xml/`), which is what a test on the home network needs.

### An APK for other phones on the same Wi-Fi

To try the app (and nearby sync) on several phones with the server on this PC:

```bash
php artisan serve --host=0.0.0.0 --port=8000        # reachable from the network (allow it in the Windows firewall)
flutter build apk --debug --dart-define=API_BASE_URL=http://192.168.1.143:8000   # this PC's address on the Wi-Fi
```

Install the one APK from `build/app/outputs/flutter-apk/app-debug.apk` on every phone: nearby sync only works between phones on **exactly the same version and build number** (`version:` in `pubspec.yaml`, shown in Settings), so raise the build number (`1.1.0+7`) whenever you change the app and install it everywhere.

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

- **Offline families**: on the login page, "Use the app offline" starts a family that lives only on its phones (or joins one with its connect code, shown in Settings on any phone of the family). It never talks to the web app. Phones find each other by the code over Bluetooth, stay connected, and keep each other up to date. See "Offline families" in [docs/api.md](../../docs/api.md).
