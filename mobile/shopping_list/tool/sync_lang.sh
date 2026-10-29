#!/bin/sh
# The phone app uses the web app's own texts, so wording is identical on both.
# Run after changing resources/lang/*.json at the project root.
set -e
cd "$(dirname "$0")/.."
cp ../../resources/lang/en.json assets/lang/en.json
cp ../../resources/lang/pt.json assets/lang/pt.json
echo "Copied the web app's texts to assets/lang"
