import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// Lab 2 *Text field*: default, focused, filled, error, disabled.
/// Focused and filled come from the controller and focus node; error shows an
/// icon plus the message under the field (never colour alone).
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.helper,
    this.errorText,
    this.enabled = true,
    this.prefixIcon,
    this.onChanged,
    this.onSubmitted,
    this.textInputAction,
    this.keyboardType,
    this.semanticId,
    this.maxLines = 1,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final String? helper;
  final String? errorText;
  final bool enabled;
  final IconData? prefixIcon;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction? textInputAction;
  final TextInputType? keyboardType;
  final String? semanticId;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    // Identifier only: a `textField: true` wrapper adds a second, non-editable
    // EditText node that swallows text typed by TalkBack or ARTEMIS.
    return Semantics(
      identifier: semanticId,
      child: TextField(
        controller: controller,
        enabled: enabled,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        textInputAction: textInputAction,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          helperText: errorText == null ? helper : null,
          errorText: errorText,
          prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
          suffixIcon: errorText == null ? null : const Icon(Icons.error_outline),
        ),
      ),
    );
  }
}

/// Search variant used on Browse: leading search icon, clear action.
class AppSearchField extends StatelessWidget {
  const AppSearchField({
    super.key,
    required this.controller,
    required this.onSubmitted,
    required this.onClear,
    this.onChanged,
    this.hint = 'Team name, topic or skill',
  });

  final TextEditingController controller;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;
  final ValueChanged<String>? onChanged;
  final String hint;

  @override
  Widget build(BuildContext context) {
    // Only the identifier is added here. Declaring `textField`/`label` on this
    // wrapper created a second, non-editable EditText node above the real one,
    // so TalkBack and ARTEMIS typed into a node that dropped the text.
    return Semantics(
      identifier: 'browse_search_field',
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) => Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: AppRadius.cardAll,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: controller,
            textInputAction: TextInputAction.search,
            onSubmitted: onSubmitted,
            onChanged: onChanged,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey.shade500),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              enabledBorder: const OutlineInputBorder(
                borderRadius: AppRadius.cardAll,
                borderSide: BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: AppRadius.cardAll,
                borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2.0),
              ),
              prefixIcon: Icon(Icons.search, color: Theme.of(context).colorScheme.primary),
              suffixIcon: value.text.isEmpty
                  ? null
                  : IconButton(tooltip: 'Clear search', icon: const Icon(Icons.close), onPressed: onClear),
            ),
          ),
        ),
      ),
    );
  }
}
