import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:permission_handler/permission_handler.dart';

/// What the radio tells the service.
class RadioEvents {
  RadioEvents({
    required this.found,
    required this.lost,
    required this.initiated,
    required this.result,
    required this.disconnected,
    required this.received,
  });

  /// A phone nearby that is looking for connections too.
  final void Function(String endpointId, String name) found;
  final void Function(String endpointId) lost;

  /// A connection is being set up (by either side): both must accept.
  final void Function(String endpointId, String name) initiated;
  final void Function(String endpointId, bool connected) result;
  final void Function(String endpointId) disconnected;
  final void Function(String endpointId, Uint8List bytes) received;
}

/// The short-range radio (Bluetooth and Wi-Fi, no internet) as the app uses it.
abstract class NearbyRadio {
  /// Make this phone visible to others, and look for theirs. False when the phone refuses (permissions, radio off).
  Future<bool> start({required String name, required RadioEvents events});

  Future<void> stop();

  Future<void> connect(String endpointId, {required String name});

  Future<void> accept(String endpointId);

  Future<void> reject(String endpointId);

  Future<void> send(String endpointId, Uint8List bytes);

  Future<void> disconnect(String endpointId);
}

/// Google's Nearby Connections, through the `nearby_connections` plugin.
class PluginRadio implements NearbyRadio {
  static const serviceId = 'app.cestou.mobile.sync';

  final _nearby = Nearby();
  RadioEvents? _events;

  @override
  Future<bool> start({required String name, required RadioEvents events}) async {
    _events = events;

    try {
      final advertising = await _nearby.startAdvertising(
        name,
        Strategy.P2P_CLUSTER,
        onConnectionInitiated: (id, info) => events.initiated(id, info.endpointName),
        onConnectionResult: (id, status) => events.result(id, status == Status.CONNECTED),
        onDisconnected: events.disconnected,
        serviceId: serviceId,
      );

      final discovering = await _nearby.startDiscovery(
        name,
        Strategy.P2P_CLUSTER,
        onEndpointFound: (id, endpointName, _) => events.found(id, endpointName),
        onEndpointLost: (id) {
          if (id != null) events.lost(id);
        },
        serviceId: serviceId,
      );

      return advertising && discovering;
    } catch (_) {
      return false; // the phone said no: Bluetooth or location is off, or a permission is missing
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _nearby.stopAdvertising();
      await _nearby.stopDiscovery();
      await _nearby.stopAllEndpoints();
    } catch (_) {}
  }

  @override
  Future<void> connect(String endpointId, {required String name}) async {
    final events = _events;
    if (events == null) return;

    try {
      await _nearby.requestConnection(
        name,
        endpointId,
        onConnectionInitiated: (id, info) => events.initiated(id, info.endpointName),
        onConnectionResult: (id, status) => events.result(id, status == Status.CONNECTED),
        onDisconnected: events.disconnected,
      );
    } catch (_) {
      events.result(endpointId, false);
    }
  }

  @override
  Future<void> accept(String endpointId) async {
    final events = _events;
    if (events == null) return;

    await _nearby.acceptConnection(
      endpointId,
      onPayLoadRecieved: (id, payload) {
        final bytes = payload.bytes;
        if (payload.type == PayloadType.BYTES && bytes != null) events.received(id, bytes);
      },
    );
  }

  @override
  Future<void> reject(String endpointId) async {
    try {
      await _nearby.rejectConnection(endpointId);
    } catch (_) {}
  }

  @override
  Future<void> send(String endpointId, Uint8List bytes) => _nearby.sendBytesPayload(endpointId, bytes);

  @override
  Future<void> disconnect(String endpointId) async {
    try {
      await _nearby.disconnectFromEndpoint(endpointId);
    } catch (_) {}
  }
}

/// Asks Android for what the radio needs: Bluetooth and nearby devices on recent versions,
/// location on older ones. Returns true when all of it is allowed.
Future<bool> askForNearbyPermissions() async {
  if (!Platform.isAndroid) return false;

  final sdk = (await DeviceInfoPlugin().androidInfo).version.sdkInt;

  final needed = <Permission>[
    if (sdk >= 31) ...[Permission.bluetoothScan, Permission.bluetoothAdvertise, Permission.bluetoothConnect],
    if (sdk >= 33) Permission.nearbyWifiDevices,
    if (sdk <= 32) Permission.locationWhenInUse,
  ];

  final results = await needed.request();
  return results.values.every((status) => status.isGranted);
}

/// Whether those permissions are already allowed (no question asked).
Future<bool> hasNearbyPermissions() async {
  if (!Platform.isAndroid) return false;

  final sdk = (await DeviceInfoPlugin().androidInfo).version.sdkInt;

  final needed = <Permission>[
    if (sdk >= 31) ...[Permission.bluetoothScan, Permission.bluetoothAdvertise, Permission.bluetoothConnect],
    if (sdk >= 33) Permission.nearbyWifiDevices,
    if (sdk <= 32) Permission.locationWhenInUse,
  ];

  for (final permission in needed) {
    if (!await permission.isGranted) return false;
  }
  return true;
}
