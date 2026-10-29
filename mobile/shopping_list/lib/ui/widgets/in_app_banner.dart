import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/activity.dart';
import '../theme.dart';

/// A banner at the top of the app for what others did on the family's lists, while the person is
/// using the app: the same words as the phone notification, with a tap to open the list. Not shown
/// for the list they are looking at (they see it happen there).
class InAppBanner {
  /// The list on screen now, if any (see [ViewingMarker]).
  static final viewing = ValueNotifier<String?>(null);

  static OverlayEntry? _entry;
  static Timer? _timer;

  static const _stays = Duration(seconds: 6);

  /// Shows the banner; answers the notices it showed (none when the person is looking at the list).
  static List<ActivityNotice> show(
    List<ActivityNotice> notices, {
    required GlobalKey<NavigatorState> navigatorKey,
    required void Function(String listUuid) open,
  }) {
    final visible = notices.where((notice) => notice.listUuid != viewing.value).toList();
    final overlay = navigatorKey.currentState?.overlay;
    if (visible.isEmpty || overlay == null) return const [];

    dismiss();
    _entry = OverlayEntry(
      builder: (context) => _BannerView(
        notices: visible,
        onOpen: (uuid) {
          dismiss();
          open(uuid);
        },
        onDismiss: dismiss,
      ),
    );
    overlay.insert(_entry!);
    _timer = Timer(_stays, dismiss);
    return visible;
  }

  static void dismiss() {
    _timer?.cancel();
    _timer = null;
    _entry?.remove();
    _entry = null;
  }

  /// What each kind of thing looks like.
  static (IconData, Color) look(String kind) => switch (kind) {
        'item_in_cart' => (Icons.shopping_cart_outlined, Tw.blue500),
        'item_purchased' => (Icons.check_circle_outline, Tw.green500),
        'item_returned' => (Icons.undo, Tw.amber600),
        'item_changed' => (Icons.edit_outlined, Tw.amber600),
        'item_removed' => (Icons.delete_outline, Tw.red600),
        'list_created' => (Icons.playlist_add, Tw.green500),
        'list_removed' => (Icons.delete_sweep_outlined, Tw.red600),
        _ => (Icons.add_shopping_cart, Tw.green500),
      };
}

/// Tells [InAppBanner] which list is on screen, for as long as this widget is.
class ViewingMarker extends StatefulWidget {
  const ViewingMarker({super.key, required this.listUuid, required this.child});

  final String listUuid;
  final Widget child;

  @override
  State<ViewingMarker> createState() => _ViewingMarkerState();
}

class _ViewingMarkerState extends State<ViewingMarker> {
  @override
  void initState() {
    super.initState();
    InAppBanner.viewing.value = widget.listUuid;
  }

  @override
  void dispose() {
    if (InAppBanner.viewing.value == widget.listUuid) InAppBanner.viewing.value = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _BannerView extends StatefulWidget {
  const _BannerView({required this.notices, required this.onOpen, required this.onDismiss});

  final List<ActivityNotice> notices;
  final void Function(String listUuid) onOpen;
  final VoidCallback onDismiss;

  @override
  State<_BannerView> createState() => _BannerViewState();
}

class _BannerViewState extends State<_BannerView> with SingleTickerProviderStateMixin {
  late final AnimationController _slide = AnimationController(vsync: this, duration: const Duration(milliseconds: 260))..forward();

  @override
  void dispose() {
    _slide.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final first = widget.notices.first;
    final (icon, color) = InAppBanner.look(first.kind);
    final more = widget.notices.length - 1;
    final lines = first.lines.take(3).toList();

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: SlideTransition(
          position: Tween(begin: const Offset(0, -1.2), end: Offset.zero).animate(CurvedAnimation(parent: _slide, curve: Curves.easeOutCubic)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: GestureDetector(
              onVerticalDragEnd: (details) {
                if ((details.primaryVelocity ?? 0) < 0) widget.onDismiss();
              },
              onTap: () => widget.onOpen(first.listUuid),
              child: Material(
                elevation: 8,
                color: dark ? Tw.gray800 : Colors.white,
                borderRadius: BorderRadius.circular(14),
                clipBehavior: Clip.antiAlias,
                child: Container(
                  decoration: BoxDecoration(border: Border(left: BorderSide(color: color, width: 5))),
                  padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(radius: 17, backgroundColor: color.withValues(alpha: 0.16), child: Icon(icon, size: 19, color: color)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(first.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: dark ? Tw.gray400 : Tw.gray500)),
                            const SizedBox(height: 2),
                            for (final line in lines)
                              Text(line, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: dark ? Colors.white : Tw.gray800)),
                            if (first.lines.length > lines.length || more > 0)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  '+${first.lines.length - lines.length + more}',
                                  style: TextStyle(fontSize: 12, color: dark ? Tw.gray400 : Tw.gray500),
                                ),
                              ),
                          ],
                        ),
                      ),
                      IconButton(visualDensity: VisualDensity.compact, icon: const Icon(Icons.close, size: 18), onPressed: widget.onDismiss),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
