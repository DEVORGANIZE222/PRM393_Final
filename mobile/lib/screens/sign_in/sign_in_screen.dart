import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_tokens.dart';
import '../../viewmodels/sign_in_viewmodel.dart';
import '../../widgets/app_card.dart';
import '../../widgets/status.dart';

/// SCR_01 Sign In (Figma `SCR_01: Sign In (FPT SSO)`).
class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SignInViewModel>();
    final busy = vm.status == SignInStatus.signingIn;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppSize.maxContentWidth),
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.lg),
              children: [
                const Center(
                  child: StatusBadge(
                    label: 'FPT University · Experiential Entrepreneurship 2026',
                    tone: Tone.warning,
                    icon: Icons.school,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Center(
                  child: Semantics(
                    label: 'EXEMatching logo',
                    image: true,
                    child: Container(
                      width: 72,
                      height: 72,
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: context.colors.surfaceContainerLowest,
                        borderRadius: AppRadius.cardAll,
                        boxShadow: cardShadow,
                      ),
                      child: Image.asset('assets/brand/logo.png'),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Semantics(
                  header: true,
                  child: Text('EXEMatching', textAlign: TextAlign.center, style: context.text.headlineMedium),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Experiential Entrepreneurship · Team Matching',
                  textAlign: TextAlign.center,
                  style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant),
                ),
                const SizedBox(height: AppSpacing.lg),
                // 3-step timeline cards with distinct high-contrast backgrounds
                const _StepCard(
                  step: '1',
                  icon: Icons.groups,
                  title: 'Form a 4–5 member team',
                  tone: Tone.warning,
                  bgColor: Color(0xFFFFF7ED),
                  borderColor: Color(0xFFFED7AA),
                ),
                const SizedBox(height: AppSpacing.sm),
                const _StepCard(
                  step: '2',
                  icon: Icons.how_to_vote,
                  title: 'Elect a team leader',
                  tone: Tone.info,
                  bgColor: Color(0xFFEFF6FF),
                  borderColor: Color(0xFFBFDBFE),
                ),
                const SizedBox(height: AppSpacing.sm),
                const _StepCard(
                  step: '3',
                  icon: Icons.verified_user,
                  title: 'Lock final roster',
                  tone: Tone.success,
                  bgColor: Color(0xFFF0FDF4),
                  borderColor: Color(0xFFBBF7D0),
                ),
                const SizedBox(height: AppSpacing.lg),
                if (vm.message != null) ...[
                  InfoBanner(
                    semanticId: 'sign_in_message',
                    tone: vm.message!.code == 'cancelled' ? Tone.info : Tone.error,
                    title: vm.message!.title,
                    message: vm.message!.cause,
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                _GoogleButton(busy: busy, onPressed: vm.signIn),
                const SizedBox(height: AppSpacing.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lock_outline, size: 14, color: context.colors.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(
                      'Restricted to enrolled roster accounts',
                      style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.step,
    required this.icon,
    required this.title,
    required this.tone,
    required this.bgColor,
    required this.borderColor,
  });

  final String step;
  final IconData icon;
  final String title;
  final Tone tone;
  final Color bgColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: AppRadius.cardAll,
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          IconTile(icon: icon, tone: tone),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(title, style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          ),
          StatusBadge(label: 'Step 0$step', tone: tone),
        ],
      ),
    );
  }
}

/// Figma SCR_01 Google button: white card, Google "G", label, trailing arrow.
class _GoogleButton extends StatelessWidget {
  const _GoogleButton({required this.busy, required this.onPressed});

  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final label = busy ? 'Signing in…' : 'Continue with Google';
    return Semantics(
      identifier: 'btn_google_sign_in',
      button: true,
      enabled: !busy,
      label: busy ? '$label, in progress' : label,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: const BoxDecoration(borderRadius: AppRadius.cardAll, boxShadow: cardShadow),
        child: Material(
          color: context.colors.surfaceContainerLowest,
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.cardAll),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: busy ? null : onPressed,
            child: SizedBox(
              height: 56,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Row(
                  children: [
                    if (busy)
                      const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2))
                    else
                      const Text(
                        'G',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Color(0xFF4285F4)),
                      ),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(child: Text(label, style: context.text.titleSmall)),
                    Icon(Icons.arrow_forward, color: context.colors.onSurfaceVariant),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
