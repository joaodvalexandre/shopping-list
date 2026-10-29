/// One thing somebody else did on a list (`GET /activity`).
class ActivityEvent {
  const ActivityEvent({
    required this.id,
    required this.kind,
    required this.actor,
    required this.listUuid,
    required this.list,
    required this.item,
    required this.quantity,
  });

  final int id;

  /// item_added, item_in_cart, item_purchased or list_created.
  final String kind;

  /// The name of who did it; null when the server itself did.
  final String? actor;
  final String listUuid;
  final String list;
  final String? item;
  final int? quantity;

  /// The same thing, said of [actor] (the name as shown).
  ActivityEvent by(String? actor) => ActivityEvent(id: id, kind: kind, actor: actor, listUuid: listUuid, list: list, item: item, quantity: quantity);

  static ActivityEvent fromJson(Map<String, dynamic> json) => ActivityEvent(
        id: (json['id'] as num).toInt(),
        kind: json['kind'] as String,
        actor: json['actor'] as String?,
        listUuid: json['list_uuid'] as String,
        list: json['list'] as String? ?? '',
        item: json['item'] as String?,
        quantity: (json['quantity'] as num?)?.toInt(),
      );
}

/// What the server said: the events newer than the cursor, and the cursor to ask from next.
class ActivityPage {
  const ActivityPage({required this.events, required this.lastId});

  final List<ActivityEvent> events;
  final int lastId;

  static ActivityPage fromJson(Map<String, dynamic> json) => ActivityPage(
        events: [for (final e in (json['data'] as List? ?? const [])) ActivityEvent.fromJson(e as Map<String, dynamic>)],
        lastId: (json['last_id'] as num?)?.toInt() ?? 0,
      );
}

/// One notification: the list it is about, and a line per thing that happened there.
class ActivityNotice {
  const ActivityNotice({required this.listUuid, required this.title, required this.lines, required this.lastEventId, this.kind = 'item_added'});

  final String listUuid;
  final String title;
  final List<String> lines;
  final int lastEventId;

  /// What the last thing was (for the icon of an in-app banner).
  final String kind;

  String get body => lines.join('\n');
}

/// Turn events into notifications, one per list, with similar things rolled together:
/// "Bia added 3 items to Barbecue", not three notifications. [t] is the app's text lookup
/// (key and `:name` parameters), so the wording is the app's, in its language.
List<ActivityNotice> buildNotices(List<ActivityEvent> events, String Function(String key, Map<String, Object> params) t) {
  final byList = <String, List<ActivityEvent>>{};
  for (final event in events) {
    (byList[event.listUuid] ??= []).add(event);
  }

  return [
    for (final entry in byList.entries)
      ActivityNotice(
        listUuid: entry.key,
        title: entry.value.first.list,
        lines: _lines(entry.value, t),
        lastEventId: entry.value.last.id,
        kind: entry.value.last.kind,
      ),
  ];
}

List<String> _lines(List<ActivityEvent> events, String Function(String, Map<String, Object>) t) {
  // The same person doing the same thing: one line, with how many
  final groups = <(String?, String), List<ActivityEvent>>{};
  for (final event in events) {
    (groups[(event.actor, event.kind)] ??= []).add(event);
  }

  return [
    for (final entry in groups.entries) _line(entry.key.$1, entry.key.$2, entry.value, t),
  ];
}

String _line(String? actor, String kind, List<ActivityEvent> events, String Function(String, Map<String, Object>) t) {
  final who = actor ?? t('app_someone', const {});
  final first = events.first;

  if (kind == 'list_created') {
    return t('app_notice_list_created', {'name': who, 'list': first.list});
  }
  if (kind == 'list_removed') {
    return t('app_notice_list_removed', {'name': who, 'list': first.list});
  }

  final key = switch (kind) {
    'item_in_cart' => 'app_notice_item_in_cart',
    'item_purchased' => 'app_notice_item_purchased',
    'item_returned' => 'app_notice_item_returned',
    'item_removed' => 'app_notice_item_removed',
    'item_changed' => 'app_notice_item_changed',
    _ => 'app_notice_item_added',
  };

  if (events.length > 1) {
    return t('${key}_many', {'name': who, 'count': events.length, 'list': first.list});
  }

  // Said with how many, when it is more than one
  final quantity = first.quantity ?? 1;
  final single = kind == 'item_added' && quantity > 1 ? '${key}_qty' : key;
  return t(single, {'name': who, 'item': first.item ?? '', 'list': first.list, 'quantity': quantity});
}
