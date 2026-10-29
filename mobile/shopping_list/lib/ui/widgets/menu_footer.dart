import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../state/menu_service.dart';
import '../theme.dart';
import 'common.dart';

Future<void> openLink(MenuLink link) async {
  final url = link.url;
  if (url == null) return;

  await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}

/// The footer links arranged in the backoffice: columns for headings with links
/// under them, then the loose links, as on the web.
class MenuFooter extends StatelessWidget {
  const MenuFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final links = context.watch<MenuService>().footer;
    if (links.isEmpty) return const SizedBox.shrink();

    final dark = context.isDark;
    final muted = dark ? Tw.gray400 : Tw.gray500;
    final strong = dark ? Tw.gray200 : Tw.gray700;

    final columns = links.where((link) => link.children.isNotEmpty).toList();
    final loose = links.where((link) => link.children.isEmpty).toList();

    Widget anchor(MenuLink link, {bool bold = false}) => InkWell(
          onTap: link.url == null ? null : () => openLink(link),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Text(
              link.label,
              style: TextStyle(fontSize: 13, color: bold ? strong : muted, fontWeight: bold ? FontWeight.w600 : FontWeight.w400),
            ),
          ),
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (columns.isNotEmpty)
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 40,
              runSpacing: 14,
              children: [
                for (final column in columns)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      anchor(column, bold: true),
                      for (final child in column.children) anchor(child),
                    ],
                  ),
              ],
            ),
          if (loose.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(alignment: WrapAlignment.center, spacing: 18, children: [for (final link in loose) anchor(link)]),
          ],
        ],
      ),
    );
  }
}
