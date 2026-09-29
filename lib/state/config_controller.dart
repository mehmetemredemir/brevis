import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/brevis_config.dart';
import '../services/brevis_bridge.dart';

/// Ayarlar ekranındaki TÜM widget'ların dinlediği tek gerçek kaynak.
///
/// Her mutasyon önce bellekte anında uygulanır (UI gecikmesiz tepki verir),
/// ardından native tarafa yazma 400ms debounce edilir — kullanıcı bir slider'ı
/// sürüklerken her piksel değişiminde MethodChannel çağrısı yapmayalım diye.
class ConfigController extends ChangeNotifier {
  ConfigController(this._bridge);

  final BrevisBridge _bridge;

  BrevisConfig _config = const BrevisConfig();
  BrevisConfig get config => _config;

  bool _loading = true;
  bool get loading => _loading;

  bool _notificationAccessGranted = false;
  bool get notificationAccessGranted => _notificationAccessGranted;

  Timer? _debounce;

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    final results = await Future.wait([
      _bridge.getConfig(),
      _bridge.isNotificationAccessGranted(),
    ]);
    _config = results[0] as BrevisConfig;
    _notificationAccessGranted = results[1] as bool;
    _loading = false;
    notifyListeners();
  }

  Future<void> refreshPermissionStatus() async {
    _notificationAccessGranted = await _bridge.isNotificationAccessGranted();
    notifyListeners();
  }

  Future<void> openNotificationAccessSettings() =>
      _bridge.openNotificationAccessSettings();

  /// Tüm ekranlar config'i güncellemek için bu tek metodu çağırır.
  void update(BrevisConfig Function(BrevisConfig current) mutator) {
    _config = mutator(_config);
    notifyListeners(); // UI anında güncellensin
    _scheduleSave();
  }

  void _scheduleSave() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _bridge.updateConfig(_config);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
