import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';

/// Gerencia a identidade única do dispositivo atual.
/// O [deviceId] é gerado uma vez e persistido em SharedPreferences.
class DeviceService {
  static const _kDeviceIdKey = 'spark_device_id';

  /// Retorna o [deviceId] único e persistido deste dispositivo.
  Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_kDeviceIdKey);
    if (id == null || id.isEmpty) {
      id = _generateId();
      await prefs.setString(_kDeviceIdKey, id);
    }
    return id;
  }

  /// Retorna um nome legível para o dispositivo atual.
  Future<String> getDeviceName() async {
    try {
      final info = DeviceInfoPlugin();
      if (kIsWeb) {
        final webInfo = await info.webBrowserInfo;
        return 'Web — ${webInfo.browserName.name}';
      } else if (Platform.isAndroid) {
        final androidInfo = await info.androidInfo;
        return 'Android — ${androidInfo.model}';
      } else if (Platform.isIOS) {
        final iosInfo = await info.iosInfo;
        return 'iOS — ${iosInfo.model}';
      } else if (Platform.isWindows) {
        final windowsInfo = await info.windowsInfo;
        return 'Windows — ${windowsInfo.computerName}';
      } else if (Platform.isMacOS) {
        final macInfo = await info.macOsInfo;
        return 'macOS — ${macInfo.model}';
      } else if (Platform.isLinux) {
        final linuxInfo = await info.linuxInfo;
        return 'Linux — ${linuxInfo.name}';
      }
    } catch (_) {}
    return 'Dispositivo desconhecido';
  }

  String _generateId() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rand = Random.secure();
    return List.generate(32, (_) => chars[rand.nextInt(chars.length)]).join();
  }
}
