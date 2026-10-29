import 'package:nearby_connections/nearby_connections.dart';

import 'local_family.dart';
import 'nearby_service.dart';
import 'radio.dart';

/// A phone of the family that was found nearby.
class FamilyPhoneFound {
  const FamilyPhoneFound({required this.person, required this.version});

  /// Whose phone it is, as it says.
  final String person;

  /// The app version it runs: only the very same one can sync.
  final String version;
}

/// Looks for the phones of an offline family by its code, before this phone has joined it:
/// the first thing someone joining does is find the family, and only then say who they are.
/// It only listens (it advertises nothing, and connects to nobody).
class LocalFamilyProbe {
  final _nearby = Nearby();
  bool _running = false;

  /// Starts looking. [found] is told of every phone of the family that shows up. False when the
  /// phone would not start looking (Bluetooth off, no permission).
  Future<bool> start(String code, void Function(FamilyPhoneFound phone) found) async {
    final tag = await (await LocalFamilyKey.derive(code)).tag();

    try {
      _running = await _nearby.startDiscovery(
        'probe',
        Strategy.P2P_CLUSTER,
        serviceId: PluginRadio.serviceId,
        onEndpointFound: (id, name, _) {
          final peer = NearbyPeer.parse(id, name);
          if (peer != null && peer.family == tag) found(FamilyPhoneFound(person: peer.person, version: peer.version));
        },
        onEndpointLost: (_) {},
      );
    } catch (_) {
      _running = false;
    }

    return _running;
  }

  Future<void> stop() async {
    if (!_running) return;

    _running = false;
    try {
      await _nearby.stopDiscovery();
    } catch (_) {}
  }
}
