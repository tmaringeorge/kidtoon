import 'package:flutter/services.dart';

/// Scutirea de la economisirea bateriei, ca Android să nu oprească radioul cu ecranul stins.
class Battery {
  static const _ch = MethodChannel('kidtoon/battery');

  static Future<bool> isUnrestricted() async {
    try {
      return await _ch.invokeMethod<bool>('isIgnoring') ?? true;
    } catch (_) {
      return true;
    }
  }

  static Future<void> requestUnrestricted() async {
    try {
      await _ch.invokeMethod<void>('request');
    } catch (_) {}
  }
}
