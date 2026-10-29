import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../state/content_service.dart';
import '../../state/settings_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/top_bar.dart';

/// A content page (About, Privacy policy, Terms...) read from the app's own copy, in the
/// chosen language, so it opens with no connection.
class PageScreen extends StatelessWidget {
  const PageScreen({super.key, required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context) {
    final content = context.watch<ContentService>();
    final language = context.watch<SettingsState>().language;
    final page = content.page(slug);
    final dark = context.isDark;

    return Scaffold(
      appBar: AppBar(
        title: Text(page == null ? '' : content.titleOf(page, language), style: const TextStyle(fontSize: 18)),
        actions: const [ThemeToggle(), SizedBox(width: 12)],
      ),
      body: ListView(
        padding: scrollPadding,
        children: [
          Panel(
            padding: const EdgeInsets.all(20),
            child: page == null
                ? Text(context.t('app_page_missing'))
                : HtmlWidget(
                    content.contentOf(page, language),
                    textStyle: TextStyle(fontSize: 15, height: 1.5, color: dark ? Tw.gray100 : Tw.gray900),
                    customStylesBuilder: (element) => switch (element.localName) {
                      'a' => {'color': dark ? '#60A5FA' : '#2563EB'},
                      'h2' => {'margin-top': '1.2em', 'font-size': '1.25em'},
                      'h3' => {'margin-top': '1em', 'font-size': '1.1em'},
                      _ => null,
                    },
                    onTapUrl: (url) => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
                  ),
          ),
        ],
      ),
    );
  }
}
