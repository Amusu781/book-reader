import 'package:flutter/services.dart';

/// Focus Mode: immersive full-screen + Android Do Not Disturb.
///
/// DND is done through a MethodChannel to MainActivity (Kotlin).
/// If the user has not granted DND access, we open the system settings
/// page once and continue reading without DND — never crash, never block.
class FocusMode {
  static const _channel = MethodChannel('com.jaycrypt.readingroom/dnd');
  bool _dndTurnedOnByUs = false;

  Future<bool> isDndGranted() async {
    try {
      return await _channel.invokeMethod<bool>('isDndGranted') ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> requestDndAccess() async {
    try {
      await _channel.invokeMethod('requestDndAccess');
    } catch (_) {
      // Settings page could not be opened; reading continues without DND.
    }
  }

  Future<void> enter() async {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    try {
      final granted = await isDndGranted();
      if (granted) {
        await _channel.invokeMethod('setDnd', {'enabled': true});
        _dndTurnedOnByUs = true;
      }
    } catch (_) {
      _dndTurnedOnByUs = false;
    }
  }

  Future<void> exit() async {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    if (_dndTurnedOnByUs) {
      try {
        await _channel.invokeMethod('setDnd', {'enabled': false});
      } catch (_) {}
      _dndTurnedOnByUs = false;
    }
  }
}
