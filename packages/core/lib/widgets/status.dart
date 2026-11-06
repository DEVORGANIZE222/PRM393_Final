import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';

enum Tone { neutral, primary, success, warning, error, info }

({Color fg, Color bg}) toneColors(BuildContext context, Tone tone) {
  final c = context.colors;
  final a = context.appColors;
  return switch (tone) {
    Tone.neutral => (fg: a.onTag, bg: a.tag),
    Tone.primary => (fg: c.onPrimaryContainer, bg: c.primaryContainer),
    Tone.success => (fg: a.success, bg: a.successContainer),
    Tone.warning => (fg: a.warning, bg: a.warningContainer),
    Tone.error => (fg: c.error, bg: c.errorContainer),
    Tone.info => (fg: a.info, bg: a.infoContainer),
  };
}

/// Status badge: always icon + text (WCAG 1.4.1, no meaning by colour alone).
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.label, this.tone = Tone.neutral, this.icon});

  final String label;
  final Tone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final t = toneColors(context, tone);
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(color: t.bg, borderRadius: AppRadius.fullAll),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: AppSize.iconSmall, color: t.fg),
              const SizedBox(width: AppSpacing.xs),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.labelSmall?.copyWith(color: t.fg),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Inline banner (info / success / warning / error) with a front-loaded title.
class InfoBanner extends StatelessWidget {
  const InfoBanner({
    super.key,
    required this.title,
    this.message,
    this.tone = Tone.info,
    this.icon,
    this.iconColor,
    this.action,
    this.semanticId,
  });

  final String title;
  final String? message;
  final Tone tone;
  final IconData? icon;
  final Color? iconColor;
  final Widget? action;
  final String? semanticId;

  IconData get _defaultIcon => switch (tone) {
    Tone.success => Icons.check_circle,
    Tone.warning => Icons.schedule,
    Tone.error => Icons.error,
    _ => Icons.info,
  };

  @override
  Widget build(BuildContext context) {
    final t = toneColors(context, tone);
    return Semantics(
      identifier: semanticId,
      container: true,
      liveRegion: tone == Tone.error,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: t.bg,
          borderRadius: AppRadius.cardAll,
          border: Border.all(color: t.fg.withValues(alpha: 0.25), width: 1.0),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon ?? _defaultIcon, color: iconColor ?? t.fg),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: context.text.titleSmall?.copyWith(
                      color: tone == Tone.error ? t.fg : context.colors.onSurface,
                    ),
                  ),
                  if (message != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(message!, style: context.text.bodyMedium),
                  ],
                  if (action != null) ...[const SizedBox(height: AppSpacing.sm), action!],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rounded-square icon tile in a tone colour (Figma step and notice icons).
class IconTile extends StatelessWidget {
  const IconTile({super.key, required this.icon, this.tone = Tone.primary, this.size = 40});

  final IconData icon;
  final Tone tone;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = toneColors(context, tone);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: t.bg, borderRadius: AppRadius.smAll),
      child: Icon(icon, size: size * 0.55, color: t.fg),
    );
  }
}

/// Circle avatar with initials, network image (or a grey "open slot").
class MemberAvatar extends StatelessWidget {
  const MemberAvatar({super.key, this.initials, this.avatarUrl, this.size = AppSize.avatar, this.verified = false});

  final String? initials;
  final String? avatarUrl;
  final double size;
  final bool verified;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (initials == null && (avatarUrl == null || avatarUrl!.isEmpty)) {
      return Semantics(
        label: 'Open slot',
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(shape: BoxShape.circle, color: context.appColors.tag),
          child: Icon(Icons.add, size: size / 2, color: c.onSurfaceVariant),
        ),
      );
    }

    Widget content;
    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      content = ClipOval(
        child: Image.network(
          avatarUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _buildInitials(context),
        ),
      );
    } else {
      content = _buildInitials(context);
    }

    if (!verified) {
      return content;
    }

    final badgeSize = (size * 0.32).clamp(10.0, 16.0);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        content,
        Positioned(
          right: -1,
          bottom: -1,
          child: Container(
            width: badgeSize,
            height: badgeSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: c.primary,
              border: Border.all(color: context.colors.surface, width: 1.5),
            ),
            child: Icon(Icons.check, size: badgeSize * 0.7, color: c.onPrimary),
          ),
        ),
      ],
    );
  }

  Widget _buildInitials(BuildContext context) {
    final c = context.colors;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: c.primaryContainer,
        border: Border.all(color: c.primary.withValues(alpha: 0.4)),
      ),
      child: Text(
        initials ?? '?',
        style: context.text.labelLarge?.copyWith(
          color: c.onPrimaryContainer,
          fontSize: (size * 0.36).clamp(10.0, 20.0),
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// Lab 2 decision D1: capacity as visual slots (filled avatars + open slots).
class SlotRow extends StatelessWidget {
  const SlotRow({super.key, required this.memberInitials, this.avatarUrls, required this.capacity});

  final List<String> memberInitials;
  final List<String?>? avatarUrls;
  final int capacity;

  @override
  Widget build(BuildContext context) {
    final open = (capacity - memberInitials.length).clamp(0, capacity);
    return Semantics(
      label: '${memberInitials.length} of $capacity members, $open open',
      excludeSemantics: true,
      child: Wrap(
        spacing: AppSpacing.sm,
        children: [
          for (var i = 0; i < memberInitials.length; i++)
            MemberAvatar(
              initials: memberInitials[i],
              avatarUrl: (avatarUrls != null && i < avatarUrls!.length) ? avatarUrls![i] : null,
              size: AppSize.avatarSmall,
            ),
          for (var k = 0; k < open; k++) const MemberAvatar(size: AppSize.avatarSmall),
        ],
      ),
    );
  }
}

class AppChip extends StatelessWidget {
  const AppChip({super.key, required this.label, required this.selected, required this.onSelected});

  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      showCheckmark: true,
      materialTapTargetSize: MaterialTapTargetSize.padded,
    );
  }
}

class AppProgressBar extends StatelessWidget {
  const AppProgressBar({super.key, required this.value, required this.label, this.tone = Tone.primary});

  final double value;
  final String label;
  final Tone tone;

  @override
  Widget build(BuildContext context) {
    final t = toneColors(context, tone);
    return Semantics(
      label: label,
      value: '${(value * 100).round()} percent',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: AppRadius.fullAll,
            child: LinearProgressIndicator(
              value: value.clamp(0, 1),
              color: tone == Tone.primary ? context.colors.primary : t.fg,
              minHeight: AppSize.progress,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(label, style: context.text.bodyMedium),
        ],
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Row(
        children: [
          Expanded(child: Text(title, style: context.text.titleMedium)),
          if (trailing != null) Text(trailing!, style: context.text.labelMedium),
        ],
      ),
    );
  }
}

/// Key-value row with a leading icon (Team Detail facts, Random Pool status).
class InfoRow extends StatelessWidget {
  const InfoRow({super.key, required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: context.colors.onSurfaceVariant),
          const SizedBox(width: AppSpacing.sm),
          Text(label, style: context.text.bodyMedium),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(value, style: context.text.labelLarge, textAlign: TextAlign.end),
          ),
        ],
      ),
    );
  }
}
