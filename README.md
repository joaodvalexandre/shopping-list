# Shopping List

A shared shopping list for families. A web app (Laravel + Livewire) where each family manages its own lists, and a Flutter mobile app that syncs with it.

- Accounts are **created by an administrator**; there is no public sign-up.
- Every family has its own members, list types and lists, and cannot see anyone else's.
- Family admins decide, **per member and per type of list**, what each person may do.
- A list can be **hidden from specific members** (the birthday person never sees the party list).
- Portuguese and English.

> **Status:** work in progress. The web app, accounts, permissions, the mobile API (v1) and the admin backoffice are done. The mobile app is still being reworked to use the API. See [Roadmap](#roadmap).

## Contents

- [How it works](#how-it-works)
- [Backoffice](#backoffice)
- [Requirements](#requirements)
- [Setup](#setup)
- [Day-to-day development](#day-to-day-development)
- [Configuration](#configuration)
- [Testing](#testing)
- [Mobile app and API](#mobile-app-and-api)
- [Security notes](#security-notes)
- [Roadmap](#roadmap)
- [License](#license)

## How it works

### Families, roles and accounts

| Role | Can do |
|---|---|
| **App admin** (you, in the [backoffice](#backoffice)) | Create and delete families, manage every member, languages, texts and pages |
| **Family admin** | Everything inside their own family: manage members, list types, permissions, and every list. Can promote any member to admin |
| **Member** | Only what their permissions allow |

Families are created in the backoffice (or from the command line: `php artisan family:create "Silva" "Joana Silva" joana@example.com`). Either way a **one-time temporary password** is shown for the family's first admin, who must choose their own on first login. The same applies to every member a family admin adds (from the **Family** menu): a temporary password is shown once, and the member must replace it on first login.

### Permissions

Each family defines its own **list types** (Groceries, Party, Pharmacy...). For every member and every type, an admin ticks what that member may do:

| Permission | Allows |
|---|---|
| View | See the lists of that type and their items |
| Add items | Add new items to those lists |
| Edit/delete items | Rename, change the quantity of, and delete items |
| Cart & purchase | Move items to the cart, back, and mark them purchased |
| Manage lists | Create, rename, delete lists of that type, and choose who they are hidden from |

Any permission implies *View*. Permissions are set when a member is created and can be changed at any time. Admins implicitly have all of them, in their own family only.

### Hidden lists

When creating or editing a list, an admin (or anyone who manages that type) can hide it from chosen members. **Hiding wins over every role, admins included.** A hidden list does not appear in lists, on the dashboard, in exports, in the mobile sync, and opening its address gives a 404, the same answer as for a list that does not exist.

If a list is hidden from every person who could manage it, nobody can edit it until one of them is un-hidden from the database. Keep at least one manager who can see it.

### Where the rules live

All access goes through one place, so the web app and the API always agree:

- `ShoppingList::visibleTo($user)` is the only way lists are queried for a signed-in user (same family, a type they may view, not hidden from them).
- `ShoppingListPolicy` answers what a user may do with a list they can see.
- Anything outside a user's reach answers **404**, never 403, so records cannot be probed.

## Backoffice

For the app owner, at **`/admin`** (built with [Filament](https://filamentphp.com)). It is a separate world from the family app: its administrators live in their own table (`admins`) and use their own login, so **no family account, whatever its role, can ever sign in to it**.

Create the first administrator once:

```bash
php artisan admin:create "Your Name" you@example.com
# asks for a password (12+ characters)
```

What you can do there:

| Section | |
|---|---|
| **Dashboard** | Families, members (and how many are still waiting for their first login), lists, items, latest families |
| **Families** | Create a family together with its first admin (a temporary password is shown once). Rename, delete (removes the family with everything in it). Each family's page lists its members |
| **Members** | Every member of every family: search, filter by family/role/status. Edit name, email and role (promote to admin), **reset password** (new temporary password, signed out everywhere), **sign out everywhere**, delete. A family can never be left without an admin |
| **Pages** | Simple content pages (privacy, about, help...) with a title and rich text **per language**, shown at `/p/<address>`. Drafts are hidden; published pages can be linked in the site footer |
| **Languages** | Switch languages on/off, choose the default, add new ones (Spanish, French...). Whatever is switched on appears in the language menu and in members' settings. The default and English (the fallback) cannot be deleted |
| **Texts** | Every text of the app, per language. The shipped text is shown next to a box where you type your own version; blank goes back to the default. Placeholders such as `:seconds` must be kept. Use **Sync texts** after adding a language or new texts to the code |
| **Administrators** | Add and remove people who can sign in to the backoffice; reset someone's two-factor setup if they lose their authenticator |

**Two-factor sign-in** (authenticator app, with recovery codes) is **required in production** and optional while developing. Each administrator sets it up from their profile.

How the texts work: the texts that ship with the app live in `resources/lang/*.json` and are the defaults. What you type in **Texts** is stored in the database and laid over them, for that language only. Only texts that exist in those files can be overridden, so framework messages (like validation errors) are never affected.

## Requirements

- PHP **8.3+** (developed on 8.5) with the extensions `mbstring`, `openssl`, `pdo_mysql`, `pdo_sqlite`, `sqlite3`, `curl`, `fileinfo`, `intl`, `zip`, `gd`, `exif`
- Composer 2.x
- Node.js 20.19+ or 22.12+ (required by Vite 8) and npm
- MySQL or MariaDB (tests run on in-memory SQLite and need no database)
- Flutter 3.47+ (only for the mobile app)

## Setup

```bash
git clone git@github.com:joaodvalexandre/shopping-list.git
cd shopping-list

composer install
cp .env.example .env
php artisan key:generate
```

Create an empty database (default name `shopping_list`), set `DB_*` in `.env`, then:

```bash
php artisan migrate --seed          # tables, item statuses, languages and their texts
php artisan admin:create            # your backoffice login (asks for name, email, password)
npm install
npm run build
```

Serve it with Laragon (it picks up the project folder) or:

```bash
php artisan serve
```

Then sign in to **`/admin`**, create a family (a temporary password is shown once), and sign in to the site with it. After pulling new changes, run `composer install` and `npm run build` again (the backoffice's own scripts are republished automatically by Composer).

## Day-to-day development

```bash
npm run dev            # Vite with hot reload
php artisan serve      # or use Laragon
php artisan migrate:fresh --seed   # rebuild the database from scratch
```

**Migrations are edited in place for now.** The project has no production database yet, so the schema lives in the original migration files and is rebuilt with `migrate:fresh`. Once a production database exists, switch to additive migrations only (never edit one that has already run).

Useful commands:

| Command | Purpose |
|---|---|
| `php artisan admin:create` | New backoffice administrator |
| `php artisan family:create "Family" "Admin name" admin@email` | New family with its first admin (the backoffice does this too) |
| `php artisan route:list` | All routes |
| `vendor/bin/pint` | Code style |

## Configuration

Everything is in `.env` (see `.env.example`). The ones worth knowing:

| Variable | Meaning |
|---|---|
| `APP_LOCALE` / `APP_FALLBACK_LOCALE` | Language used before the database is set up (`pt`), and the fallback for any missing text (`en`). Which languages are offered, and the default, are managed in the backoffice. Each member can choose their own in **Settings** |
| `BROADCAST_CONNECTION` | `log` (default) or `pusher`. With Pusher, open browsers of a family refresh when someone changes a list |
| `PUSHER_*`, `VITE_PUSHER_*` | Pusher credentials, only for realtime refresh. The channel is private per family and carries only ids, never content |
| `SANCTUM_EXPIRATION` | Minutes a mobile device token stays valid (default 180 days) |
| `SESSION_DRIVER`, `CACHE_STORE`, `QUEUE_CONNECTION` | `file`, `file`, `sync` by default; tables for `database` drivers are included |

## Testing

```bash
php artisan test
```

The suite uses Pest and in-memory SQLite. It focuses on what must never break:

- one family can never see or change another's data, on the web and the API
- hidden lists stay hidden, from admins too
- every permission works on its own (a member who can add items cannot edit them, and so on)
- login throttling, forced password change, last-admin protection
- the mobile sync: permissions per field, last-write-wins conflicts, deletions, clock skew
- the backoffice: family accounts can never enter it, every screen works, languages/texts/pages behave (overrides apply, framework messages untouched, drafts stay hidden, pasted scripts do not run)

Tests do not need a built frontend (`npm run build`).

## Mobile app and API

The Flutter app lives in [`mobile/shopping_list`](mobile/shopping_list). It talks to the web app through a token-authenticated JSON API (`/api/v1`): one login per device, family-scoped data, the same permissions as the web, and a single two-way sync endpoint that works offline-first.

- **API reference:** [`docs/api.md`](docs/api.md)
- **App notes and status:** [`mobile/shopping_list/README.md`](mobile/shopping_list/README.md)

## Security notes

- No public registration; temporary passwords are shown once and must be changed on first login.
- Logins (web and API) are rate limited per email and IP.
- A password reset by an admin signs that member out everywhere, including every phone.
- State-changing actions are POST/PUT/DELETE only, with CSRF protection on the web.
- The realtime channel is private and content-free.
- Device tokens can be listed and revoked (`GET/DELETE /api/v1/me/devices`) and expire on their own.
- The backoffice has its own guard and table, so a family account can never reach it; two-factor sign-in is required in production; administrators' passwords need 12+ characters, and the two-factor secret is stored encrypted.

If you find a vulnerability, please tell the maintainer privately rather than opening a public issue.

## Roadmap

- [x] Upgrade to current Laravel, Livewire, Tailwind, Vite and Flutter
- [x] Families, accounts, roles, per-list-type permissions, hidden lists
- [x] Mobile API v1 with device tokens and delta sync
- [x] Admin backoffice (Filament): families, members, languages, texts, pages, administrators
- [ ] Mobile app: login, local database, offline queue and sync, same look and permissions as the web
- [ ] Nearby sync between family members' Android phones
- [ ] Push notifications, item categories, audit log, data export/delete, backups

## License

[MIT](LICENSE) © João Alexandre
