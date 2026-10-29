import 'dart:convert';
import 'dart:typed_data';

/// Nearby Connections sends at most about 32 KB in one payload, and a list of unsent changes
/// can be longer. A message is cut into frames that each carry a numbered piece of its text,
/// and put back together on the other side.
class Frames {
  /// Bytes of a message in one frame, before the base64 that carries them (which makes it a third longer).
  static const pieceBytes = 16000;

  /// [messageId] tells the frames of one message from those of another.
  static List<Uint8List> split(Map<String, dynamic> message, int messageId) {
    final bytes = utf8.encode(jsonEncode(message));
    final count = (bytes.length / pieceBytes).ceil().clamp(1, 1 << 30);

    return [
      for (var i = 0; i < count; i++)
        Uint8List.fromList(utf8.encode(jsonEncode({
          'm': messageId,
          'n': count,
          'k': i,
          'd': base64.encode(bytes.sublist(i * pieceBytes, (i + 1) * pieceBytes > bytes.length ? bytes.length : (i + 1) * pieceBytes)),
        }))),
    ];
  }
}

/// Collects frames until a whole message is there.
class FrameAssembler {
  final _pieces = <int, Map<int, List<int>>>{};

  /// Add a frame; returns the message when this was its last missing piece, else null.
  /// A frame that is not one of ours is ignored.
  Map<String, dynamic>? add(List<int> frame) {
    try {
      final json = jsonDecode(utf8.decode(frame)) as Map<String, dynamic>;
      final id = (json['m'] as num).toInt();
      final count = (json['n'] as num).toInt();
      final index = (json['k'] as num).toInt();

      final pieces = _pieces.putIfAbsent(id, () => {});
      pieces[index] = base64.decode(json['d'] as String);
      if (pieces.length < count) return null;

      _pieces.remove(id);
      final bytes = [for (var i = 0; i < count; i++) ...pieces[i]!];

      return jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}
