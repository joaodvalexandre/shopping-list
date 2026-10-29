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
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(own ? '$name  (${context.t('app_you')})' : name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle!, style: TextStyle(fontSize: 13, color: muted), overflow: TextOverflow.ellipsis),
              ],
              const SizedBox(height: 10),
              Wrap(spacing: 6, runSpacing: 6, children: pills),
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
        padding: const EdgeInsets.fromLTRB(16, 14, 4, 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
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

/// What both Family pages start with: that this person is in the family, which one, as whom, and
/// how it is connected (to the web app, or to the family's phones). Same layout online and offline.
class FamilyHeader extends StatelessWidget {
  const FamilyHeader({
    super.key,
    required this.familyName,
    required this.you,
    required this.statusText,
    required this.statusIcon,
    required this.statusColor,
    this.onRename,
  });

  final String familyName;

  /// "On this phone you are Ana".
  final String you;
  final String statusText;
  final IconData statusIcon;
  final Color statusColor;

  /// Set when this person may rename the family (an admin of an offline family).
  final VoidCallback? onRename;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final muted = dark ? Tw.gray400 : Tw.gray500;

    return Panel(
      padding: const EdgeInsets.fromLTRB(18, 16, 10, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.check_circle, size: 18, color: dark ? Tw.green500 : Tw.green600),
            const SizedBox(width: 8),
            Expanded(child: Text(context.t('app_family_you_in'), style: TextStyle(fontSize: 13, color: muted))),
          ]),
          Row(children: [
            Expanded(
              child: Text(
                familyName.isEmpty ? context.t('app_offline_family_unknown') : familyName,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
            ),
            if (onRename != null)
              IconButton(
                tooltip: context.t('app_family_rename'),
                icon: Icon(Icons.edit_outlined, color: dark ? Tw.amber400 : Tw.amber600),
                onPressed: onRename,
              ),
          ]),
          const SizedBox(height: 2),
          Text(you, style: TextStyle(fontSize: 13, color: muted)),
          const SizedBox(height: 10),
          Row(children: [
            Icon(statusIcon, size: 16, color: statusColor),
            const SizedBox(width: 6),
            Expanded(child: Text(statusText, style: TextStyle(fontSize: 12, color: statusColor, fontWeight: FontWeight.w600))),
          ]),
        ],
      ),
    );
  }
}
