import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/brevis_config.dart';
import '../models/model_download_state.dart';

/// `com.leti.brevis.bridge.BrevisMethodChannelHandler` ile konuşan tek nokta.
/// Kanal adı Kotlin tarafındaki `CHANNEL_NAME` sabitiyle BİREBİR aynı olmalı.
class BrevisBridge {
  BrevisBridge._();
  static final BrevisBridge instance = BrevisBridge._();

  static const MethodChannel _channel = MethodChannel('com.leti.brevis/settings');
  static const EventChannel _modelStatusChannel = EventChannel('com.leti.brevis/modelStatus');

  Future<BrevisConfig> getConfig() async {
    final String raw = await _channel.invokeMethod<String>('getConfig') ?? '{}';
    return BrevisConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> updateConfig(BrevisConfig config) async {
    await _channel.invokeMethod<bool>(
      'updateConfig',
      {'configJson': jsonEncode(config.toJson())},
    );
  }

  Future<bool> isNotificationAccessGranted() async {
    final granted = await _channel.invokeMethod<bool>('isNotificationAccessGranted');
    return granted ?? false;
  }

  Future<void> openNotificationAccessSettings() async {
    await _channel.invokeMethod<void>('openNotificationAccessSettings');
  }

  /// Kotlin tarafı [{packageName, label, icon?}, ...] döner (icon: base64 PNG, opsiyonel).
  Future<List<InstalledApp>> getInstalledApps() async {
    final List<dynamic> raw =
        await _channel.invokeMethod<List<dynamic>>('getInstalledApps') ?? [];
    return raw
        .map((e) => InstalledApp.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  // ---------------- Model yaşam döngüsü ----------------

  Future<ModelDownloadState> getModelStatus() async {
    final String raw = await _channel.invokeMethod<String>('getModelStatus') ?? '{}';
    return ModelDownloadState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> startModelDownload() => _channel.invokeMethod<void>('startModelDownload');

  Future<void> cancelModelDownload() => _channel.invokeMethod<void>('cancelModelDownload');

  /// AI toggle'dan BAĞIMSIZ, ayrı bir eylem — sadece disk alanı boşaltır.
  Future<void> deleteModel() => _channel.invokeMethod<void>('deleteModel');

  /// Model indirme ilerlemesini gerçek zamanlı dinler (polling yok).
  Stream<ModelDownloadState> watchModelStatus() {
    return _modelStatusChannel.receiveBroadcastStream().map(
          (raw) => ModelDownloadState.fromJson(jsonDecode(raw as String) as Map<String, dynamic>),
        );
  }
}

class InstalledApp {
  final String packageName;
  final String label;
  final String? iconBase64;

  const InstalledApp({required this.packageName, required this.label, this.iconBase64});

  factory InstalledApp.fromMap(Map<String, dynamic> map) => InstalledApp(
        packageName: map['packageName'] as String,
        label: map['label'] as String,
        iconBase64: map['icon'] as String?,
      );
}
