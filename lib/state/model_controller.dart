import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/model_download_state.dart';
import '../services/brevis_bridge.dart';

/// Model indirme/silme durumunu tutan tek gerçek kaynak. `watchModelStatus()`
/// akışına abone olur, ekran açık olduğu sürece ilerleme çubuğu polling YAPMADAN
/// gerçek zamanlı güncellenir.
class ModelController extends ChangeNotifier {
  ModelController(this._bridge);

  final BrevisBridge _bridge;

  ModelDownloadState _state = const ModelDownloadState();
  ModelDownloadState get state => _state;

  StreamSubscription<ModelDownloadState>? _subscription;

  Future<void> init() async {
    _state = await _bridge.getModelStatus();
    notifyListeners();

    _subscription = _bridge.watchModelStatus().listen((state) {
      _state = state;
      notifyListeners();
    });
  }

  Future<void> startDownload() => _bridge.startModelDownload();

  Future<void> cancelDownload() => _bridge.cancelModelDownload();

  /// AI toggle'dan bağımsız, ayrı bir eylem.
  Future<void> deleteModel() => _bridge.deleteModel();

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
