import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';

/// Lab 2 *App bar*: default (title), with back (nested screens), with actions.
/// Back uses the platform back behaviour, so Android system Back matches it.
///
/// Top-level tabs (`showBack: false`) use the Figma brand header: the logo,
/// the product name as an overline, then the screen title.
class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  const AppTopBar({super.key, required this.title, this.actions, this.showBack});

  final String title;
  final List<Widget>? actions;

  /// Null = automatic (shown when the route can pop).
  final bool? showBack;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final brand = showBack == false;
    final heading = Semantics(header: true, child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis));
    return AppBar(
      automaticallyImplyLeading: showBack == null,
      leading: showBack == true
          ? IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Back',
              onPressed: () {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                } else {
                  context.go('/home');
                }
              },
            )
          : null,
      titleSpacing: brand ? AppSpacing.lg : null,
      title: brand
          ? Row(
              children: [
                ExcludeSemantics(child: Image.asset('assets/brand/logo.png', width: 32, height: 32)),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('EXEMatching', style: context.text.bodySmall),
                      DefaultTextStyle.merge(style: context.text.titleMedium, child: heading),
                    ],
                  ),
                ),
              ],
            )
          : heading,
      titleTextStyle: brand ? null : context.text.titleMedium,
      actions: actions,
      shape: const Border(bottom: BorderSide(color: Color(0x0F101828))),
    );
  }
}
