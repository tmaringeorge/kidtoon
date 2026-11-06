import 'package:flutter/services.dart';

/// Pe ce rulează aplicația: televizor (telecomandă) sau telefon/tabletă (atingere).
class Device {
  static const _ch = MethodChannel('kidtoon/device');
  static bool isTv = false;

  static Future<void> detect() async {
    try {
      isTv = await _ch.invokeMethod<bool>('isTv') ?? false;
    } catch (_) {
      isTv = false;
    }
  }
}
