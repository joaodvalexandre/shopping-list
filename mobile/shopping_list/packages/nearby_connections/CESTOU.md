# Cestou's copy of nearby_connections 4.3.0

The only change from the published package is in
`android/src/main/java/com/pkmnapps/nearby_connections/NearbyConnectionsPlugin.java`:
advertising, discovery and the connection request all use `setLowPower(true)` (Bluetooth/BLE only, no upgrade to Wi-Fi), and the request also `setDisruptiveUpgrade(false)`.

Why: nearby sync only runs while the server cannot be reached, and with the default options Google
Play services switched Wi-Fi on by itself, so a phone someone had turned off Wi-Fi on went back onto
the home network.

Remove this folder (and the `path:` in pubspec.yaml) if the package ever offers the option itself.
