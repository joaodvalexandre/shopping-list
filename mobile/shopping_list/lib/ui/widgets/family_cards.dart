import 'package:flutter/material.dart';

import '../theme.dart';
import 'common.dart';

/// A person of the family, as a card: their name, a line under it (an email, or whose phone it
/// is), the pills that say what they are, and the actions. The server family's page and the
/// offline one both use it, so they look the same.
class FamilyMemberCard extends StatelessWidget {
  const FamilyMemberCard({
    super.key,
    required this.name,
    required this.own,
    required this.pills,
    required this.actions,
    this.subtitle,
    this.onTap,
  });

  final String name;

  /// This phone's own person: marked "(you)".
  final bool own;
  final String? subtitle;
  final List<Widget> pills;
  final List<Widget> actions;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final muted = context.isDark ? Tw.gray400 : Tw.gray500;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(own ? '$name  (${context.t('app_you')})' : name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle!, style: TextStyle(fontSize: 13, color: muted), overflow: TextOverflow.ellipsis),
              ],
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 4, children: pills),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: actions),
            ],
          ),
        ),
      ),
    );
  }
}

/// A list type of the family, as a card: its name, how many lists it has, and the actions
/// (or, when it cannot go, a note saying why).
class FamilyTypeCard extends StatelessWidget {
  const FamilyTypeCard({super.key, required this.name, required this.listsCount, required this.actions, this.note});

  final String name;
  final int listsCount;
  final List<Widget> actions;

  /// Said at the end instead of a delete button: "in use".
  final String? note;

  @override
  Widget build(BuildContext context) {
    final muted = context.isDark ? Tw.gray400 : Tw.gray500;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                  Text('${context.t('lists')}: $listsCount', style: TextStyle(fontSize: 13, color: muted)),
                ],
              ),
            ),
            ...actions,
            if (note != null) Padding(padding: const EdgeInsets.only(right: 12), child: Text(note!, style: TextStyle(fontSize: 12, color: muted))),
          ],
        ),
      ),
    );
  }
}
