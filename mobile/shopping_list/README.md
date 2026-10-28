# Shopping List - mobile app

Flutter companion app for the Shopping List web app (see the [project README](../../README.md)).

> **Status: being reworked.** Today the app is a standalone, local-only shopping list. Its old web-sync code talks to API endpoints that were **removed** (they served every family's data without authentication), so **sync with the web app is currently disabled**. The replacement API is ready and documented; the app is the next piece of work. See [What is planned](#what-is-planned).

## What works today

- Shopping lists and items, stored on the device (`shared_preferences`)
- Add / edit / delete lists and items; move items to the cart and mark them purchased
- Progress statistics per list and overall
- Portuguese and English
- Light and dark appearance

## What is planned

The goal is for the app to **behave and look like the web app**, not to be a separate product.

**Sign-in and sync (API v1)** - [reference](../../docs/api.md)
- Sign in with the same email and password as the web app; one token per device, revocable from the web
- First login with a temporary password asks the member to choose their own
- A local database plus an outbox of offline changes, sent and received with the single `POST /api/v1/sync` call
- Conflicts resolved per field, last write wins; deletions propagate as tombstones

**Same rules as the web**
- Buttons appear only if the member holds the permission (add items, edit items, cart & purchase, manage lists), per list type, using the `permissions` the API returns
- Lists hidden from the member simply do not exist on the phone
- Admins and members who manage a list type can choose who a list is hidden from
- List types come from the family

**Same look as the web**
- Same layout, colours, spacing, icons and wording as the Laravel views, in light and dark

**Nearby sync (Android)**
- Phones of the same family find each other (Android Nearby Connections) and exchange changes directly, using the same sync protocol and a server-issued family key, so a stranger's phone cannot join. Needs one prior sync with the server to obtain the key.

## Development

Requirements: Flutter 3.47+ (Dart 3.8+).

```bash
flutter pub get          # install dependencies
flutter analyze          # static analysis
flutter test             # tests
flutter run              # run on a connected device or emulator
```

Build:

```bash
flutter build apk --release
```

Android builds need the SDK licences accepted once: `flutter doctor --android-licenses`.

### Known issues

- `test/widget_test.dart` fails: it builds `MyApp` without the `LocaleService` provider that `main.dart` now requires.
- `lib/services/web_api_service.dart` and `connection_manager.dart` still target the removed API and will be replaced by the v1 client.

### Project structure

```
lib/
├── main.dart                  App entry point, providers
├── models/                    Shopping list and item models
├── services/
│   ├── shopping_lists_service.dart   Local data and business logic
│   ├── web_api_service.dart          Legacy API client (to be replaced by the v1 client)
│   ├── connection_manager.dart       Connectivity monitoring
│   └── custom_locale_delegate.dart   Language handling
├── screens/                   List detail screen
├── widgets/                   Cards, dialogs, item tiles, sync status
├── l10n/                      pt / en translations (.arb)
├── pages/ , utils/            App-icon generator (development tool, see ICON_UPDATE_INSTRUCTIONS.md)
```

### Dependencies

| Package | Used for |
|---|---|
| `provider` | State management |
| `shared_preferences` | Local storage (until the local database lands) |
| `http` | API calls |
| `connectivity_plus` | Detecting connectivity (returns a *list* of active connections since v6) |
| `intl`, `flutter_localizations` | Translations |
| `flutter_launcher_icons` (dev) | Generating the launcher icon |

### App icon

See [ICON_UPDATE_INSTRUCTIONS.md](ICON_UPDATE_INSTRUCTIONS.md).
