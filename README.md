# Cestou

A shared shopping list for families (*cestou*: from *cesta*, Portuguese for basket). A web app (Laravel + Livewire) where each family manages its own lists, and a Flutter mobile app that syncs with it.

- Accounts are **created by an administrator**; there is no public sign-up.
- Every family has its own members, list types and lists, and cannot see anyone else's.
- Family admins decide, **per member and per type of list**, what each person may do.
- A list can be **hidden from specific members** (the birthday person never sees the party list).
- Portuguese and English.

> **Status:** work in progress. The web app, accounts, permissions, the mobile API (v1) and the admin backoffice are done. The Android app works offline and syncs through the API. See [Roadmap](#roadmap).

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

Families are created in the backoffice (or from the command line: `php artisan family:create "Silva" "Joana Silva" joana@example.com`). Either way the family's first admin gets a **temporary password: the family's name, exactly as written** (so a family called `Silva` signs in with `Silva`). It is also shown on screen after creating them. The same applies to every member a family admin adds (from the **Family** menu) and to every password reset. On first login, on the web or in the app, the person can do nothing but choose their own password, and the new one must differ from the family name.

> The family name is easy to pass on but also easy to guess, so it only works until the first login. Hand the email and the first-time password to the right person, and do not leave an account waiting for a first login for long (the backoffice shows who is still waiting).

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

### The demo family

To try the web and phone apps with something in them: `php artisan db:seed --class=DemoSeeder` (never in production). It creates the family *Silva* with **joana@demo.test** (admin), **bia@demo.test** (adds items and uses the cart in Groceries, only looks at Pharmacy, cannot see *Bia's birthday*) and **rui@demo.test** (edits items and manages lists in Groceries). Everyone's first-time password is `Silva`.

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

The first administrator is a **super administrator**. Everyone else sees and does only what their [roles](#roles-and-permissions) allow.

What you can do there:

| Section | |
|---|---|
| **Dashboard** | Totals with a 14-day trend (families, members and how many still wait for their first login, lists, items), new families and members per month, system information, latest families |
| **Families** | Create a family together with its first admin (the first-time password, the family name, is shown after saving). Rename, delete (removes the family with everything in it). Each family's page lists its members |
| **Members** | Every member of every family: search, filter by family/role/status. Edit name, email and role (promote to admin), **reset password** (new temporary password, signed out everywhere), **sign out everywhere**, delete. A family can never be left without an admin |
| **Pages** | Simple content pages (privacy, about, help...) with a title and rich text **per language**, shown at `/p/<address>`. Drafts are hidden |
| **Menus** | Every link of the site's **navbar**, **account menu** and **footer** (see [Menus](#menus)) |
| **Languages** | Switch languages on/off, choose the default, add new ones (Spanish, French...). Whatever is switched on appears in the language menu and in members' settings. The default and English (the fallback) cannot be deleted |
| **Texts** | Every text of the app, per language. The shipped text is shown next to a box where you type your own version; blank goes back to the default. Placeholders such as `:seconds` must be kept. Use **Sync texts** after adding a language or new texts to the code |
| **Administrators** | Add and remove people who can sign in to the backoffice, give them roles; reset someone's two-factor setup if they lose their authenticator |
| **Roles** | Create roles and tick what each may do, area by area |
| **Permissions** | The list of everything that can be allowed; add custom ones |

### Roles and permissions

What a backoffice administrator may do is decided by **roles**, each a set of **permissions** named `area.action` (for example `pages.update`). The areas are families, members, pages, languages, texts, administrators, roles and permissions; the actions are view, create, update and delete (texts only have view and update). An administrator can hold several roles, and gets the combination.

These roles ship with the app (and are seeded):

| Role | Allows |
|---|---|
| **Super administrator** | Everything, always, including permissions added later. Cannot be changed or deleted, and there must always be at least one |
| **Support** | See families and members, add families and members, reset passwords |
| **Content editor** | Write pages, edit texts |
| **Translator** | See languages, edit texts |
| **Viewer** | See everything, change nothing |

Rules worth knowing:

- Built-in roles and permissions can be adjusted but never deleted, and a built-in permission's key can never change (the code looks it up by that key). Custom roles are free; custom permissions have no effect until code checks them.
- Giving roles is itself a permission (`roles.update`), so someone who can edit administrators but not roles cannot promote themselves.
- Screens and buttons an administrator may not use are hidden, and opening them anyway answers 403.
- The family app's own roles (family admin, member) and per-list-type permissions are a separate thing, described [above](#how-it-works).

### Menus

The navbar, the account menu (under the person's name) and the footer are **not hard-coded**: they are drawn from the links you arrange in **Menus**. Each link:

| | |
|---|---|
| **Where** | Navbar, account menu or footer |
| **Points at** | A **content page**; one of the **app's own screens** (dashboard, shopping lists, family members, list types, settings, log in); an **address** (`https://...` or a path of this site); or a **heading** that only holds other links |
| **Shown to** | Everyone, visitors who are not signed in, anyone signed in, or family admins only. A screen only offers the audiences it is meant for (the dashboard is never offered to visitors) |
| **Text** | Per language. Optional for a page or a screen, which bring their own name |
| **Under** | Another link of the same place: in the navbar it becomes a dropdown, in the footer a column. Two levels at most |
| **Order, active, new tab** | Drag to reorder; switch a link off without deleting it; open in a new tab |

Things to know:

- Hiding a link does **not** protect a page; it only decides who is offered it. Every screen still checks permissions itself.
- Only `http(s)` addresses and paths of this site are linked, never `javascript:` and the like. A link to a draft page, or a heading with nothing under it, is not drawn.
- The app never leaves a signed-in person without a way around: if no navbar link is meant for them, the dashboard and shopping lists are shown anyway.
- The phone app keeps its own copy of the languages, texts, pages and links (`GET /api/v1/content`), so it shows them offline; the app's own web screens are left out, as it has its own. Each link's audience is applied on the phone.

### Seeders

`php artisan db:seed` (also part of `migrate --seed`) is safe to run again at any time:

| Seeder | Adds |
|---|---|
| `StatusSeeder` | The three item statuses |
| `LanguageSeeder` | Portuguese (default) and English |
| `PermissionSeeder`, `RoleSeeder` | Every permission and the shipped roles. Existing roles keep what was ticked, except the super administrator, which always gets every permission |
| `TranslationSeeder` | One editable row per text and language |
| `MenuSeeder` | Starter links (see [Menus](#menus)), only when there are no links at all |
| `PageSeeder` | Starter pages (About, Privacy policy, Terms of use) in both languages. **They are a starting point: read them, adjust them and add your contact details in the backoffice before going public.** A page that exists is never overwritten |

**Two-factor sign-in** (authenticator app, with recovery codes) is **required in production** and optional while developing. Each administrator sets it up from their profile.

How the texts work: the texts that ship with the app live in `resources/lang/*.json` and are the defaults. What you type in **Texts** is stored in the database and laid over them, for that language only. Only texts that exist in those files can be overridden, so framework messages (like validation errors) are never affected.

## Requirements

- PHP **8.3+** (developed on 8.5) with the extensions `mbstring`, `openssl`, `pdo_mysql`, `pdo_sqlite`, `sqlite3`, `curl`, `fileinfo`, `intl`, `zip`, `gd`, `exif`, `sodium` (signs what lets family phones trust each other offline)
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
php artisan migrate --seed          # tables, statuses, languages, texts, roles, permissions, starter pages
php artisan admin:create            # your backoffice login (asks for name, email, password)
npm install
npm run build
```

Serve it with Laragon (it picks up the project folder) or:

```bash
php artisan serve
```

Then sign in to **`/admin`**, create a family, and sign in to the site with the admin's email and the family name as password. After pulling new changes, run `composer install` and `npm run build` again (the backoffice's own scripts are republished automatically by Composer).

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
| `php artisan admin:create` | New backoffice super administrator |
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

- No public registration; the first-time password (the family name) only gets someone as far as choosing their own, on the web and on the phone.
- Backoffice access is role-based: every screen is checked by a policy, and the panel refuses a resource that has none.
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
- [x] Admin backoffice (Filament): families, members, languages, texts, pages, administrators, roles and permissions
- [x] Mobile app: login, local database, offline queue and sync, same look and permissions as the web, texts/pages/menus kept locally
- [x] Nearby sync between family members' Android phones (same app version only), and notifications about what others did
- [ ] Item categories, audit log, data export/delete, backups, push via Firebase (instant notifications)

## License

[MIT](LICENSE) © João Alexandre
