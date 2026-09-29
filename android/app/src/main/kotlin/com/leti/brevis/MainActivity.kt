package com.leti.brevis

import com.leti.brevis.bridge.BrevisMethodChannelHandler
import com.leti.brevis.bridge.ModelStatusStreamHandler
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * Flutter'ın tek Activity'si. İki görevi var:
 *  1) "com.leti.brevis/settings" MethodChannel'ını BrevisMethodChannelHandler'a bağlamak.
 *  2) "com.leti.brevis/modelStatus" EventChannel'ını ModelStatusStreamHandler'a bağlamak
 *     (model indirme ilerlemesinin Flutter'a gerçek zamanlı akıtılması için).
 *
 * Servisin kendisi (BrevisNotificationListenerService) bu Activity'den TAMAMEN bağımsız
 * çalışır — kullanıcı ayarlar ekranını hiç açmasa bile servis, diskten yüklediği son
 * config ile arka planda çalışmaya devam eder.
 */
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            BrevisMethodChannelHandler.CHANNEL_NAME
        ).setMethodCallHandler(BrevisMethodChannelHandler(applicationContext))

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            ModelStatusStreamHandler.CHANNEL_NAME
        ).setStreamHandler(ModelStatusStreamHandler(applicationContext))
    }
}

