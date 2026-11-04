import 'package:flutter/widgets.dart';

/// Spacing scale from Lab 2 `DESIGN.md` §2 (8-point grid).
abstract final class AppSpacing {
  static const double xs = 4; // spacing-4
  static const double sm = 8; // spacing-8
  static const double md = 12; // spacing-12
  static const double lg = 16; // spacing-16: screen margin, card padding
  static const double xl = 24; // spacing-24: section rhythm
  static const double xxl = 32; // spacing-32: hero padding

  static const EdgeInsets screen = EdgeInsets.all(lg);
}

/// Corner radius tokens (`radius-sm|md|lg|full`).
abstract final class AppRadius {
  static const double sm = 8; // buttons, chips, inputs, banners
  static const double md = 12; // cards, sheets
  static const double lg = 16; // dialogs
  static const double full = 999; // pills, avatars

  static const double button = 10; // Figma buttons
  static const double card = 14; // Figma cards and panels

  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius buttonAll = BorderRadius.all(Radius.circular(button));
  static const BorderRadius cardAll = BorderRadius.all(Radius.circular(card));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius fullAll = BorderRadius.all(Radius.circular(full));
}

/// Elevation levels: 0 = border only, 1 = pressed card, 2 = pinned bar, 3 = dialog.
abstract final class AppElevation {
  static const double none = 0;
  static const double card = 1;
  static const double bar = 3;
  static const double dialog = 6;
}

/// Fixed sizes from the component rules.
abstract final class AppSize {
  static const double touchTarget = 48; // minimum interactive size (WCAG 2.5.5)
  static const double button = 48;
  static const double icon = 24;
  static const double iconSmall = 16;
  static const double avatar = 40;
  static const double avatarSmall = 32;
  static const double illustration = 96;
  static const double logo = 80;
  static const double progress = 8;
  static const double appBar = 64;
  static const double navBar = 80;
  static const double maxContentWidth = 560; // ≥ 600 dp layouts
}
