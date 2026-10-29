# Mobile API v1

JSON API used by the mobile app. Base path: `/api/v1`.

- **One token per device.** Sign in with email and password; the token identifies that phone and can be revoked.
- **Family-scoped.** A token only ever reaches its user's family, and only the lists that user may see. The permissions and hidden lists are exactly those of the web app.
- **Offline-first.** There is one sync endpoint: the phone sends what it changed while offline and receives everything it is missing.

All requests and responses are JSON. Send `Accept: application/json` and, for bodies, `Content-Type: application/json`.

## Conventions

| | |
|---|---|
| Auth header | `Authorization: Bearer <token>` |
| Times | ISO-8601 in UTC with milliseconds, e.g. `2026-10-28T21:01:16.123Z` (the device list uses `+00:00` offsets instead). Any ISO-8601 value is accepted when sending |
| IDs | Lists and items are identified by a **uuid** that the phone generates itself, so they can be created offline. Numeric ids are only used for list types and users |
| Item status | `to_buy`, `in_cart`, `purchased` |

### Errors

| Status | Meaning |
|---|---|
| `401` | Missing, invalid, expired or revoked token |
| `403` | The token is valid but lacks the ability for this route (a first-login token used for anything but changing the password) |
| `404` | Not found, **or not visible to you**; the two are deliberately indistinguishable |
| `422` | Validation failed: `{"message": "...", "errors": {"field": ["..."]}}` |
| `429` | More than 60 requests per minute from one user or IP |

## Authentication

### `POST /auth/login`

```json
{ "email": "ana@example.com", "password": "secret", "device_name": "Ana's Pixel" }
```

```json
{
  "token": "12|xxxxxxxx",
  "token_type": "Bearer",
  "password_change_required": false,
  "user": { "id": 3, "name": "Ana", "email": "ana@example.com" }
}
```

Wrong email or password both answer `422` with the same message. After 5 failed attempts for the same email and IP, further attempts (even with the right password) answer `422` with a "try again in N seconds" message for about a minute.

**First login.** Members are created with a temporary password, which is their family's name (as written). The new password must differ from it. For them, `password_change_required` is `true` and the token can **only** call `PUT /me/password` and `POST /auth/logout`; everything else answers `403`. The app should show a "choose your password" screen.

### `PUT /me/password`

Works with either kind of token.

```json
{ "current_password": "temp-pass", "password": "new-pass-123", "password_confirmation": "new-pass-123" }
```

Returns the same shape as login, with a **new full token** and `password_change_required: false`. Every previous token of the user (including the one used) is revoked, so other devices must sign in again. Passwords need 8+ characters with letters and numbers.

### `POST /auth/logout`

Revokes the token used for the request.

## The signed-in user

### `GET /me`

Who you are and what you may do. The sync response includes the same block as `me`; call this on its own only when you need it without syncing.

```json
{
  "user": { "id": 3, "name": "Ana", "email": "ana@example.com", "role": "member", "locale": "pt", "must_change_password": false },
  "family": { "id": 1, "name": "Silva" },
  "list_types": [ { "id": 1, "name": "Groceries" }, { "id": 2, "name": "Party" } ],
  "permissions": {
    "1": { "can_view": true,  "can_add_items": true,  "can_edit_items": false, "can_change_status": true,  "can_manage_lists": false },
    "2": { "can_view": false, "can_add_items": false, "can_edit_items": false, "can_change_status": false, "can_manage_lists": false }
  },
  "members": []
}
```

- `permissions` is keyed by list type id. Admins get `true` everywhere. **Use it to show or hide the same buttons as the web app**; the server enforces it regardless.
- `members` (id and name of the other family members) is only filled for users who manage at least one list type; it feeds the "hide this list from..." picker.

### `GET /me/devices`

```json
[ { "id": 12, "name": "Ana's Pixel", "last_used_at": "2026-10-28T20:55:00+00:00", "created_at": "2026-10-01T09:00:00+00:00", "current": true } ]
```

### `DELETE /me/devices/{id}`

Signs a device out remotely (a lost phone). Only your own devices; anything else is `404`.

## Sync

### `POST /sync`

One round trip: apply the phone's changes, then return what the phone is missing.

```json
{
  "since": "2026-10-28T21:00:00.000Z",
  "known_lists": ["<list uuid>", "..."],
  "changes": {
    "lists": [
      {
        "uuid": "<list uuid>",
        "name": "Weekly shop", "name_changed_at": "2026-10-28T20:59:10.120Z",
        "list_type_id": 1,
        "hidden_from": [5, 7],
        "deleted_at": null
      }
    ],
    "items": [
      {
        "uuid": "<item uuid>", "list_uuid": "<list uuid>",
        "name": "Milk",     "name_changed_at":     "2026-10-28T20:59:11.000Z",
        "quantity": 2,       "quantity_changed_at": "2026-10-28T20:59:11.000Z",
        "status": "in_cart", "status_changed_at":   "2026-10-28T21:00:02.500Z",
        "deleted_at": null
      }
    ]
  }
}
```

| Field | Meaning |
|---|---|
| `since` | The `server_time` returned by the previous sync. Omit (or `null`) on the very first sync to receive everything |
| `known_lists` | uuids of **every list the phone currently holds**. The server uses it to send lists the phone has never seen, and deletions of lists it holds |
| `changes.lists` / `changes.items` | Only what changed locally since the last successful sync. Send a field only if it changed, together with its `*_changed_at` time. Omit `changes` to just pull |
| `deleted_at` | Set (to the time of deletion) to delete. Deleting wins over any edit |
| `hidden_from` | User ids (from `me.members`) who must not see this list. Replaces the previous set. Only for those who may manage the list; never includes yourself or people from other families |

Limits: 500 lists, 2000 items and 1000 `known_lists` per request; names up to 255 characters; quantity 1-9999.

Response:

```json
{
  "server_time": "2026-10-28T21:01:11.000Z",
  "results": {
    "lists": { "<uuid>": { "status": "applied" } },
    "items": {
      "<uuid>": { "status": "rejected", "reason": "forbidden", "fields": ["status"] }
    }
  },
  "lists": [ { "uuid": "...", "name": "...", "name_changed_at": "...", "list_type_id": 1, "updated_at": "...", "deleted_at": null, "hidden_from": [5] } ],
  "items": [ { "uuid": "...", "list_uuid": "...", "name": "...", "name_changed_at": "...", "quantity": 1, "quantity_changed_at": "...", "status": "to_buy", "status_changed_at": "...", "updated_at": "...", "deleted_at": null } ],
  "visible_list_uuids": ["..."],
  "me": { "...": "same as GET /me" }
}
```

### What the phone must do with the response

1. **Replace its local copy** of every list and item returned, field by field. The server's values are authoritative after conflict resolution.
2. **Delete** any entry returned with a non-null `deleted_at`.
3. **Drop every local list that is not in `visible_list_uuids`** (and its items). That is how a list disappears when it gets hidden from you or your permission is withdrawn, without a deletion record.
4. Store `server_time` and send it as `since` next time. It is deliberately a few seconds behind the real time so a slow concurrent write is never missed; the resulting repeats are harmless because applying the same data twice changes nothing.
5. Remove from its outbox the changes whose `results` entry is `applied` or `ignored`. Show `rejected` ones to the user instead of retrying them forever.
6. Refresh the permission-driven UI from `me`.

### Results

Per pushed list/item uuid:

| `status` | `reason` | Meaning |
|---|---|---|
| `applied` | | Accepted (fields that lost a conflict are simply not overwritten; that is not an error) |
| `ignored` | `deleted` | The record was already deleted on the server; edits to it are dropped |
| `ignored` | `unknown` | Created and deleted while offline; nothing to do |
| `rejected` | `forbidden` | You lack the permission. `fields` lists what was refused when the rest was applied |
| `rejected` | `not_found` | The list does not exist for you (deleted, hidden from you, or no `view` permission) |
| `rejected` | `invalid` | Malformed for the server's rules (unknown list type, empty name, a uuid that is not yours, an item moved to another list) |

### Conflict resolution

Every synced field has its own change time, so two phones editing *different* fields of the same item both keep their edits.

- A pushed field replaces the server's value only if its `*_changed_at` is **strictly newer**. On a tie the server wins.
- Times more than 5 minutes ahead of the server clock are treated as "now", so a phone with a wrong clock cannot win every conflict forever.
- Deletion beats edits. A deleted record stays on the server as a tombstone so every device finds out.
- A new record can be created only with the right permission; a new item asking for a status other than `to_buy` gets `to_buy` unless the user may use the cart.

### Permissions per field

| Pushed | Needs |
|---|---|
| New list | Manage lists on the chosen type |
| List `name`, `hidden_from`, deletion | Manage lists on the list's type |
| New item | Add items |
| Item `name`, `quantity`, deletion | Edit items |
| Item `status` | Cart & purchase |

### What is pulled

- Lists the user may see (same family, a type they may view, not hidden from them), with their items.
- Changed since `since`; plus, in full, any visible list not in `known_lists` (newly granted or un-hidden).
- Tombstones for lists in `known_lists` and for items of visible lists.
- `hidden_from` on a list is included only for users who may manage it.

## Menus

### `GET /menus?locale=pt`

Public (no token needed). The navbar, account menu and footer links arranged in the backoffice, in the given language (an unknown or missing one falls back to the default). With a token, links meant only for signed-in people or family admins are included for those who may see them.

```json
{
  "locale": "pt",
  "navbar": [ { "label": "Sobre", "url": "https://example.com/p/about?lang=pt", "new_tab": false, "children": [] } ],
  "user_menu": [],
  "footer": [ { "label": "Legal", "url": null, "new_tab": false, "children": [ { "label": "Política de privacidade", "url": "https://example.com/p/privacy?lang=pt", "new_tab": false, "children": [] } ] } ]
}
```

A `url` of `null` is a heading that only holds its `children`. Open the URLs in the browser. The web app's own screens (dashboard, lists...) are left out: the app has its own.

## Health

### `GET /health`

Public. `{"status": "ok", "time": "..."}`. Use it to tell whether the server is reachable.
