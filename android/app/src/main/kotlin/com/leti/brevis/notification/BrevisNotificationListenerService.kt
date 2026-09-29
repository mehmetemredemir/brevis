package com.leti.brevis.notification

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import com.leti.brevis.R
import com.leti.brevis.ai.AiSummaryEngine
import com.leti.brevis.config.ConfigRepository
import kotlinx.coroutines.*

/**
 * Sistemin bize WhatsApp bildirimlerini ilettiği ana giriş noktası.
 *
 * Görevleri:
 *  1) Gelen her bildirimi SessionManager'a devretmek (state machine kararını orası verir).
 *  2) SessionManager "gizle" derse cancelNotification() çağırmak (bileklik titremesin).
 *  3) AI özeti hazır olduğunda YENİ bir bildirim olarak basmak (bileklik sadece 1 kez titrer).
 *  4) Foreground Service olarak kalıcı, düşük öncelikli bir bildirimle canlı kalmak.
 */
class BrevisNotificationListenerService : NotificationListenerService() {

    // Servisin kendi ömrüyle sınırlı coroutine scope'u.
    private val serviceScope = CoroutineScope(SupervisorJob() + Dispatchers.Default)

    private lateinit var configRepository: ConfigRepository
    private lateinit var sessionManager: SessionManager
    private lateinit var aiSummaryEngine: AiSummaryEngine

    override fun onCreate() {
        super.onCreate()
        configRepository = ConfigRepository.getInstance(applicationContext)
        aiSummaryEngine = AiSummaryEngine.getInstance(applicationContext)

        sessionManager = SessionManager(onAiSummaryTriggered = { session, isClosing ->
            handleAiSummaryRequest(session, isClosing)
        })

        serviceScope.launch { configRepository.loadFromDisk() }

        startAsForegroundService()
    }

    override fun onListenerConnected() {
        super.onListenerConnected()
        // Sistem bize bağlandı — burada geçmiş aktif bildirimleri taramak da mümkün
        // (getActiveNotifications()) ama MVP için şimdilik sadece yeni gelenleri dinliyoruz.
    }

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        super.onNotificationPosted(sbn)

        // Kendi attığımız AI özet bildirimlerini asla kendi mantığımıza sokmayalım
        // (sonsuz döngü / kendi kendini filtreleme riskine karşı).
        if (sbn.packageName == applicationContext.packageName) return

        val extras = sbn.notification.extras
        val title = extras.getCharSequence(Notification.EXTRA_CONVERSATION_TITLE)?.toString()
            ?: extras.getCharSequence(Notification.EXTRA_TITLE)?.toString()
            ?: return
        val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString() ?: return

        // Grup bildirimlerinde gönderen bilgisi genelde EXTRA_TITLE_BIG veya
        // MessagingStyle mesajlarında ayrıca gelir; MVP için basitçe title'ı kullanıyoruz,
        // ileride NotificationCompat.MessagingStyle parse edilerek gönderen netleştirilebilir.
        val sender = title

        val config = configRepository.snapshot()

        val shouldHide = sessionManager.handleIncomingMessage(
            config = config,
            packageName = sbn.packageName,
            conversationTitle = title,
            sender = sender,
            text = text
        )

        if (shouldHide) {
            cancelNotification(sbn.key)
        }
        // shouldHide == false ise HİÇBİR ŞEY YAPMIYORUZ — bildirim sisteme/bilekliğe
        // olduğu gibi devam ediyor. İlk 6 mesajın istendiği gibi normal geçmesi budur.
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification) {
        super.onNotificationRemoved(sbn)
        // Kullanıcı bildirimi telefonundan silerse burada ek bir temizlik gerekmiyor,
        // state SessionManager'da bağımsız olarak yaşıyor.
    }

    private fun handleAiSummaryRequest(session: ChatSession, isClosingSummary: Boolean) {
        serviceScope.launch {
            val messagesSnapshot = synchronized(session) { session.pendingBuffer.toList() }
            if (messagesSnapshot.isEmpty()) return@launch

            val summaryText = runCatching {
                aiSummaryEngine.summarize(
                    chatTitle = session.conversationTitle,
                    messages = messagesSnapshot
                )
            }.getOrElse {
                // MediaPipe çağrısı başarısız olursa (model yüklenmedi vb.) sessizce
                // basit bir fallback özet üretelim ki kullanıcı mesajları hiç kaçırmasın.
                fallbackSummary(messagesSnapshot)
            }

            postAiSummaryNotification(
                chatTitle = session.conversationTitle,
                summaryText = summaryText,
                isClosingSummary = isClosingSummary
            )
        }
    }

    private fun fallbackSummary(messages: List<BufferedMessage>): String {
        val count = messages.size
        val lastSender = messages.lastOrNull()?.sender ?: ""
        return "$count yeni mesaj ($lastSender ve diğerleri)"
    }

    private fun postAiSummaryNotification(chatTitle: String, summaryText: String, isClosingSummary: Boolean) {
        ensureSummaryChannel()

        val title = if (isClosingSummary) "$chatTitle · Kapanış Özeti" else "$chatTitle · Özet"

        val notification = NotificationCompat.Builder(this, SUMMARY_CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_brevis_summary)
            .setContentTitle(title)
            .setContentText(summaryText)
            .setStyle(NotificationCompat.BigTextStyle().bigText(summaryText))
            .setPriority(NotificationCompat.PRIORITY_HIGH) // bileklik bu özet için 1 kez titresin
            .setAutoCancel(true)
            .build()

        val manager = getSystemService(NotificationManager::class.java)
        val notificationId = chatTitle.hashCode()
        manager.notify(notificationId, notification)
    }

    private fun ensureSummaryChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java)
        if (manager.getNotificationChannel(SUMMARY_CHANNEL_ID) == null) {
            val channel = NotificationChannel(
                SUMMARY_CHANNEL_ID,
                "Brevis AI Özetleri",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Filtrelenen sohbetler için tek satırlık AI özetleri"
            }
            manager.createNotificationChannel(channel)
        }
    }

    // ---------------- Foreground Service kalıcılığı ----------------

    private fun startAsForegroundService() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                FGS_CHANNEL_ID,
                "Brevis Arka Plan Servisi",
                NotificationManager.IMPORTANCE_MIN // kullanıcıyı rahatsız etmesin, sadece görünür olsun
            )
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }

        val fgsNotification = NotificationCompat.Builder(this, FGS_CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_brevis_status)
            .setContentTitle("Brevis aktif")
            .setContentText("Bildirimleriniz sessizce özetleniyor")
            .setPriority(NotificationCompat.PRIORITY_MIN)
            .setOngoing(true)
            .build()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                FGS_NOTIFICATION_ID,
                fgsNotification,
                android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
            )
        } else {
            startForeground(FGS_NOTIFICATION_ID, fgsNotification)
        }
    }

    override fun onDestroy() {
        sessionManager.shutdown()
        serviceScope.cancel()
        super.onDestroy()
    }

    companion object {
        private const val SUMMARY_CHANNEL_ID = "brevis_ai_summary"
        private const val FGS_CHANNEL_ID = "brevis_foreground_status"
        private const val FGS_NOTIFICATION_ID = 1001
    }
}
