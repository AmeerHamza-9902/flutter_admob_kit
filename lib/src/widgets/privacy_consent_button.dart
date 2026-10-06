import 'package:flutter/material.dart';

import '../consent_manager.dart';

/// Settings entry point, visible only when Google UMP requires privacy options.
class PrivacyConsentButton extends StatefulWidget {
  const PrivacyConsentButton({
    super.key,
    this.child = const Text('Privacy choices'),
    this.onCompleted,
  });

  /// Supply a localized label when needed.
  final Widget child;
  final ValueChanged<bool>? onCompleted;

  @override
  State<PrivacyConsentButton> createState() => _PrivacyConsentButtonState();
}

class _PrivacyConsentButtonState extends State<PrivacyConsentButton> {
  bool _showing = false;

  Future<void> _show() async {
    if (_showing) return;
    _showing = true;
    final shown = await ConsentManager.instance.showPrivacyOptionsForm();
    _showing = false;
    if (mounted) widget.onCompleted?.call(shown);
  }

  @override
  Widget build(BuildContext context) {
    final consent = ConsentManager.instance;
    return ListenableBuilder(
      listenable: consent,
      builder: (context, _) {
        if (!consent.isPrivacyOptionsRequired) return const SizedBox.shrink();
        return TextButton(
          onPressed: consent.isBusy ? null : _show,
          child: widget.child,
        );
      },
    );
  }
}
