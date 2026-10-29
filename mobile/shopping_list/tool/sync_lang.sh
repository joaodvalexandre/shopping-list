#!/bin/sh
# The phone app ships with a copy of the web app's languages, texts, pages (About, Privacy,
# Terms...) and menu links, so a fresh install works before its first connection. It then
# keeps itself up to date from GET /api/v1/content. Run this after changing the texts in
# resources/lang/*.json, or the pages and menus (ideally on a freshly seeded database).
set -e
cd "$(dirname "$0")/../../.."
php artisan mobile:export-content
