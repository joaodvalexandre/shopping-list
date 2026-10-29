import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/content.dart';
import '../../data/repository.dart';
import '../../state/auth_state.dart';
import '../../state/content_service.dart';
import '../../state/settings_state.dart';
import '../screens/page_screen.dart';
import '../theme.dart';
import 'common.dart';

extension MenuLinks on BuildContext {
  /// The links of a menu ('navbar', 'user_menu', 'footer') for whoever is looking:
  /// signed out, a member, or a family admin; in the app's language.
  List<MenuLink> menuLinks(String location) {
    final signedIn = watch<AuthState>().status == AuthStatus.signedIn;
    final admin = watch<Repository>().me?.isAdmin ?? false;

    return watch<ContentService>().links(
      location,
      language: watch<SettingsState>().language,
      viewer: !signedIn ? Viewer.guest : (admin ? Viewer.familyAdmin : Viewer.member),
    );
  }
}

/// A page opens inside the app, from the local copy; an address opens in the browser.
Future<void> openLink(BuildContext context, MenuLink link) async {
  final page = link.page;
  if (page != null) {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => PageScreen(slug: page)));
    return;
  }

  final url = link.url;
  if (url == null) return;

  // A link the backoffice got wrong (or a phone with no browser) is not worth an error
  try {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (_) {}
}

/// The footer links arranged in the backoffice: columns for headings with links
/// under them, then the loose links, as on the web.
class MenuFooter extends StatelessWidget {
  const MenuFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final links = context.menuLinks('footer');
    if (links.isEmpty) return const SizedBox.shrink();

    final dark = context.isDark;
    final muted = dark ? Tw.gray400 : Tw.gray500;
    final strong = dark ? Tw.gray200 : Tw.gray700;

    final columns = links.where((link) => link.children.isNotEmpty).toList();
    final loose = links.where((link) => link.children.isEmpty).toList();

    Widget anchor(MenuLink link, {bool bold = false}) => InkWell(
          onTap: link.goesSomewhere ? () => openLink(context, link) : null,
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
