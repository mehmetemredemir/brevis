package com.leti.brevis.bridge

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.provider.Settings
import android.text.TextUtils
import android.util.Base64
import com.leti.brevis.ai.AiSummaryEngine
import com.leti.brevis.ai.ModelManager
import com.leti.brevis.config.ConfigRepository
import com.leti.brevis.notification.BrevisNotificationListenerService
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import java.io.ByteArrayOutputStream

/**
 * Flutter arayüzündeki ayarlar ekranı (hangi uygulamalar / hangi sohbetler / ne zaman)
 * ile Kotlin tarafındaki ConfigRepository arasındaki tek köprü.
 *
 * Kanal adı: "com.leti.brevis/settings"
 *
 * Desteklenen metodlar:
 *  - "updateConfig"            (args: configJson: String) -> Boolean
 *  - "isNotificationAccessGranted" ()                       -> Boolean
 *  - "openNotificationAccessSettings" ()                    -> null
 *  - "getInstalledApps" ()                                   -> List<Map<String,String>> (packageName, label, icon?)
 */
class BrevisMethodChannelHandler(private val context: Context) : MethodChannel.MethodCallHandler {

    private val ioScope = CoroutineScope(Dispatchers.IO)
    private val configRepository = ConfigRepository.getInstance(context)
    private val modelManager = ModelManager.getInstance(context)
    private val json = Json { ignoreUnknownKeys = true; encodeDefaults = true }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getConfig" -> {
                // Flutter ayarlar ekranı açılırken mevcut (diskten yüklenmiş) config'i okur.
                result.success(configRepository.currentConfigJson())
            }

            "updateConfig" -> {
                val configJson = call.argument<String>("configJson")
                if (configJson == null) {
                    result.error("INVALID_ARGS", "configJson eksik", null)
                    return
                }
                ioScope.launch {
                    runCatching { configRepository.updateConfig(configJson) }
                        .onSuccess { result.success(true) }
                        .onFailure { result.error("PARSE_ERROR", it.message, null) }
                }
            }

            "isNotificationAccessGranted" -> {
                result.success(isNotificationListenerEnabled(context))
            }

            "openNotificationAccessSettings" -> {
                val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                context.startActivity(intent)
                result.success(null)
            }

            "getInstalledApps" -> {
                result.success(queryInstalledLaunchableApps(context))
            }

            "getModelStatus" -> {
                result.success(json.encodeToString(modelManager.state.value))
            }

            "startModelDownload" -> {
                modelManager.startDownload()
                result.success(true)
            }

            "cancelModelDownload" -> {
                modelManager.cancelDownload()
                result.success(true)
            }

            "deleteModel" -> {
                modelManager.deleteModel()
                // Servis belleğinde yüklü bir LlmInference varsa onu da temizle,
                // yoksa silinen dosya diskte gitse bile RAM'de kullanılmaya devam eder.
                AiSummaryEngine.getInstance(context).invalidate()
                result.success(true)
            }

            else -> result.notImplemented()
        }
    }

    /**
     * Kullanıcı "Bildirim Erişimi" iznini Ayarlar'dan manuel vermiş mi kontrolü.
     * Bu izin runtime permission değildir, sadece sistem ayarından açılır — bu yüzden
     * uygulama her açılışında bunu kontrol edip kullanıcıyı yönlendirmeli.
     */
    private fun isNotificationListenerEnabled(context: Context): Boolean {
        val enabledListeners = Settings.Secure.getString(
            context.contentResolver, "enabled_notification_listeners"
        ) ?: return false
        val myComponent = ComponentName(context, BrevisNotificationListenerService::class.java)
        return enabledListeners.split(":").any {
            !TextUtils.isEmpty(it) && ComponentName.unflattenFromString(it) == myComponent
        }
    }

    /**
     * Kullanıcının ana ekranında ikonu olan (yani gerçekten kullandığı) TÜM uygulamaları
     * listeler — artık mesajlaşma uygulamalarıyla sınırlı değil, herhangi bir uygulama
     * izlenebilir. Manifest'teki `<queries><intent> ACTION_MAIN/CATEGORY_LAUNCHER </intent>`
     * beyanı olmadan bu sorgu Android 11+'ta sessizce boş döner — bkz. AndroidManifest_EKLENECEK.xml.
     *
     * Her uygulamanın küçük bir ikon önizlemesini (96x96 PNG, base64) de ekliyoruz ki
     * Flutter tarafındaki liste sadece isimden ibaret kalmasın — düzinelerce uygulama
     * arasında ismiyle ayırt etmek zor olabiliyor.
     */
    private fun queryInstalledLaunchableApps(context: Context): List<Map<String, String>> {
        val pm = context.packageManager
        val launcherIntent = Intent(Intent.ACTION_MAIN, null).apply {
            addCategory(Intent.CATEGORY_LAUNCHER)
        }

        return pm.queryIntentActivities(launcherIntent, PackageManager.MATCH_ALL)
            .asSequence()
            .map { it.activityInfo.packageName }
            .distinct()
            .filter { it != context.packageName } // Brevis kendini listelemesin
            .mapNotNull { pkg ->
                runCatching {
                    val appInfo = pm.getApplicationInfo(pkg, 0)
                    val label = pm.getApplicationLabel(appInfo).toString()
                    val entry = mutableMapOf("packageName" to pkg, "label" to label)
                    runCatching { drawableToBase64Png(pm.getApplicationIcon(pkg)) }
                        .getOrNull()
                        ?.let { entry["icon"] = it }
                    entry
                }.getOrNull()
            }
            .sortedBy { it["label"]?.lowercase() ?: "" }
            .toList()
    }

    private fun drawableToBase64Png(drawable: Drawable, size: Int = 96): String {
        val bitmap = if (drawable is BitmapDrawable && drawable.bitmap != null) {
            drawable.bitmap
        } else {
            val width = drawable.intrinsicWidth.coerceAtLeast(1)
            val height = drawable.intrinsicHeight.coerceAtLeast(1)
            Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888).also { bmp ->
                val canvas = Canvas(bmp)
                drawable.setBounds(0, 0, canvas.width, canvas.height)
                drawable.draw(canvas)
            }
        }
        val scaled = Bitmap.createScaledBitmap(bitmap, size, size, true)
        val stream = ByteArrayOutputStream()
        scaled.compress(Bitmap.CompressFormat.PNG, 100, stream)
        return Base64.encodeToString(stream.toByteArray(), Base64.NO_WRAP)
    }

    companion object {
        const val CHANNEL_NAME = "com.leti.brevis/settings"
    }
}
