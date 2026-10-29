# Family Shopper's copy of nearby_connections 4.3.0

The only change from the published package is in
`android/src/main/java/com/pkmnapps/nearby_connections/NearbyConnectionsPlugin.java`:
every call to Google's Nearby Connections uses the application's `Context` instead of the `Activity`.

Why: a client made from an Activity is torn down by Google Play services when that Activity is
destroyed (closing the app, swiping it away), taking the connections to the family's other phones
with it. With the application context they last as long as the app's process does, which a
foreground service keeps alive.

Remove this folder (and the `path:` in pubspec.yaml) if the package ever does the same.
