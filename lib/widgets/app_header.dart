import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/app_theme.dart';

/// The one header for every employee-app screen.
///
/// Home, History and Profile already agreed on the shape — rounded-bottom
/// navy block over [AppColors.bg] — but each hand-rolled its own title
/// size and its own gradient Container. Monetization and Apply for Leave
/// used square-bottomed bars instead, and Apply for Leave's title was
/// centred because it inherited [AppBar]'s default centring.
///
/// This is the reconciled version. Screens using it should not also set
/// [Scaffold.appBar] — place it as the first child of the body instead.
///
/// ```dart
/// const AppHeader(
///   title: 'Leave History',
///   subtitle: 'Every request that has been settled.',
/// )
/// ```
class AppHeader extends StatelessWidget {
  const AppHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.eyebrow,
    this.showBack = false,
    this.onBack,
    this.trailing,
    this.bottom,
  });

  /// Screen title. Always left-aligned, always the same size.
  final String title;

  /// Optional supporting line. One sentence, sentence case.
  final String? subtitle;

  /// Optional all-caps label above the title (Profile's "PROFILE").
  final String? eyebrow;

  /// Show a back arrow above the title. True for pushed pages
  /// (Apply for Leave), false for tab screens.
  final bool showBack;

  /// Defaults to [Navigator.maybePop].
  final VoidCallback? onBack;

  /// Optional widget on the title row's trailing edge.
  final Widget? trailing;

  /// Optional content rendered inside the header block, below the title —
  /// Home's overview card. Keeps that card on the navy rather than forcing
  /// Home to rebuild its own header around it.
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Navy header means light status-bar icons on every screen, which was
      // previously set per-screen and missed in places.
      value: SystemUiOverlayStyle.light,
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: AppColors.headerGradient,
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(28),
            bottomRight: Radius.circular(28),
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0x38131F3A),
              blurRadius: 20,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, showBack ? 4 : 16, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showBack)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: onBack ?? () => Navigator.maybePop(context),
                      icon: const Icon(Icons.arrow_back),
                      color: Colors.white,
                      iconSize: 22,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 40,
                        minHeight: 40,
                      ),
                      splashRadius: 22,
                      tooltip: 'Back',
                    ),
                  ),
                if (eyebrow != null) ...[
                  if (showBack)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Transform.translate(
                        offset: const Offset(-9, 0),
                        child: IconButton(
                          onPressed:
                              onBack ?? () => Navigator.maybePop(context),
                          icon: const Icon(Icons.arrow_back),
                          color: Colors.white,
                          iconSize: 22,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 40,
                            minHeight: 40,
                          ),
                          splashRadius: 22,
                          tooltip: 'Back',
                        ),
                      ),
                    ),
                  Text(
                    eyebrow!.toUpperCase(),
                    style: AppText.eyebrow(color: Colors.white70),
                  ),
                  const SizedBox(height: 10),
                ],
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: AppText.display(
                          size: 27,
                          weight: FontWeight.w700,
                          color: Colors.white,
                          height: 1.15,
                        ),
                      ),
                    ),
                    if (trailing != null) ...[
                      const SizedBox(width: 12),
                      trailing!,
                    ],
                  ],
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    subtitle!,
                    style: AppText.body(
                      size: 13,
                      weight: FontWeight.w500,
                      color: Colors.white70,
                      height: 1.35,
                    ),
                  ),
                ],
                if (bottom != null) ...[const SizedBox(height: 20), bottom!],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
