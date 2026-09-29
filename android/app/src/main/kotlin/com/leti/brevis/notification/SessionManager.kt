package com.leti.brevis.notification

import com.leti.brevis.config.BrevisConfig
import kotlinx.coroutines.*
import java.util.concurrent.ConcurrentHashMap

/**
 * Tüm aktif sohbetlerin state machine'ini yönetir.
 *
 * PİL VERİMLİLİĞİ NOTU:
 * Sohbet başına ayrı bir Handler/Timer/Thread AÇMIYORUZ. Bunun yerine tek bir
 * SupervisorJob'a bağlı paylaşılan CoroutineScope kullanıyoruz. Her sohbetin
 * "cooldown" beklemesi, o sohbete özel TEK bir suspend edilmiş coroutine ile
 * temsil ediliyor; delay() sırasında coroutine hiçbir CPU tüketmez, sadece
 * sistem alarm/dispatcher kuyruğunda bekler. Yeni mesaj geldiğinde eski job
 * iptal edilip aynı coroutine yeniden kurulur (debounce) — bu sayede 50 aktif
 * sohbet olsa bile arka planda 50 "iş parçacığı" değil, 50 hafif suspend
 * noktası vardır.
 */
class SessionManager(
    private val onAiSummaryTriggered: suspend (ChatSession, isClosingSummary: Boolean) -> Unit,
    private val scope: CoroutineScope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
) {
    private val sessions = ConcurrentHashMap<String, ChatSession>()

    private fun getOrCreate(chatKey: String, packageName: String, title: String): ChatSession =
        sessions.getOrPut(chatKey) { ChatSession(chatKey, packageName, title) }

    /**
     * Ana giriş noktası. NotificationListenerService.onNotificationPosted burayı çağırır.
     *
     * @return true ise bildirim SİSTEMDEN GİZLENMELİ (cancelNotification çağrılmalı),
     *         false ise bildirim NORMAL şekilde geçmeli (dokunulmamalı).
     */
    fun handleIncomingMessage(
        config: BrevisConfig,
        packageName: String,
        conversationTitle: String,
        sender: String,
        text: String,
        nowMillis: Long = System.currentTimeMillis()
    ): Boolean {
        // Uygulama/sohbet izlenmiyorsa ya da takvim dışındaysa hiç dokunma.
        if (!config.isPackageMonitored(packageName)) return false
        if (!config.isChatMonitored(conversationTitle)) return false
        config.activeSchedule?.let { if (!it.isActiveNow()) return false }

        val chatKey = "$packageName::$conversationTitle"
        val session = getOrCreate(chatKey, packageName, conversationTitle)
        session.lastMessageAtMillis = nowMillis

        // Öncelikli kelime eşleşmesi: AI beklemeden ANINDA orijinal haliyle geçir.
        // Not: FILTERING'deyken bile bu mesaj gizlenmez, sadece tampon sayacına dahil edilir
        // (aşağıda kayıt için buffer'a da ekliyoruz ki özet bağlamı kopmasın).
        val isImportant = config.containsImportantKeyword(text)

        synchronized(session) {
            when (session.state) {
                ChatState.IDLE -> {
                    handleIdleState(config, session, sender, text, nowMillis)
                }
                ChatState.FILTERING, ChatState.COOLDOWN -> {
                    handleFilteringState(config, session, sender, text, nowMillis)
                }
            }
        }

        return !isImportant && session.state != ChatState.IDLE
    }

    private fun handleIdleState(
        config: BrevisConfig,
        session: ChatSession,
        sender: String,
        text: String,
        nowMillis: Long
    ) {
        // Burst penceresi süresi dolmuşsa sayaç sıfırlanır.
        if (nowMillis - session.burstWindowStartMillis > config.burstWindowMillis) {
            session.burstWindowStartMillis = nowMillis
            session.burstMessageCount = 0
        }
        session.burstMessageCount++

        if (session.burstMessageCount >= config.messageThresholdToFilter) {
            // ---> FİLTRE AKTİF DURUMU'na geçiş
            session.state = ChatState.FILTERING
            session.pendingBuffer.add(BufferedMessage(sender, text, nowMillis))
            armCooldownTimer(config, session)
        }
        // Eşiğe ulaşmadıysa IDLE'da kal, bildirim normal şekilde geçer (dokunulmaz).
    }

    private fun handleFilteringState(
        config: BrevisConfig,
        session: ChatSession,
        sender: String,
        text: String,
        nowMillis: Long
    ) {
        session.state = ChatState.FILTERING // COOLDOWN'daysa bile yeni mesaj geldi, tekrar aktif filtreleme
        armCooldownTimer(config, session) // sessizlik zamanlayıcısını sıfırla (debounce)

        if (!config.aiEnabled) {
            // AI KAPALI: hiçbir özet üretilmiyor, sadece sessizce gizlemeye devam ediyoruz.
            // pendingBuffer'ı yine de sınırlı tutuyoruz ki uzun süren gruplarda bellek
            // sınırsızca büyümesin (özet olmadığı için eski mesajları saklamanın anlamı yok).
            if (session.pendingBuffer.size >= MAX_BUFFER_WHEN_AI_DISABLED) {
                session.pendingBuffer.clear()
            }
            session.pendingBuffer.add(BufferedMessage(sender, text, nowMillis))
            return
        }

        session.pendingBuffer.add(BufferedMessage(sender, text, nowMillis))
        if (session.pendingBuffer.size >= config.aiSummaryThreshold) {
            triggerAiSummary(session, isClosingSummary = false)
        }
    }

    /**
     * Sessizlik zamanlayıcısını (yeniden) kurar. Aynı sohbet için önceki job varsa iptal edilir
     * — bu, "her mesajda sıfırlanan 5 dakikalık zamanlayıcı" gereksinimini, sürekli yeni
     * coroutine yaratmadan (eskisini cancel edip yenisini launch ederek) karşılar.
     */
    private fun armCooldownTimer(config: BrevisConfig, session: ChatSession) {
        session.cooldownJob?.cancel()
        session.cooldownJob = scope.launch {
            delay(config.cooldownMillis)
            // Bu noktaya ulaşıldıysa süre boyunca hiç yeni mesaj gelmedi demektir
            // (aksi halde bu job zaten cancel edilmiş olurdu).
            session.state = ChatState.COOLDOWN
            if (config.aiEnabled && session.pendingBuffer.isNotEmpty()) {
                triggerAiSummary(session, isClosingSummary = true)
            } else {
                // AI kapalıysa kapanış özeti de atılmaz — sohbet sessizce NORMAL DURUM'a döner.
                session.resetToIdle()
            }
        }
    }

    private fun triggerAiSummary(session: ChatSession, isClosingSummary: Boolean) {
        scope.launch {
            // NOT: AI çağrısı ve sonucun sisteme bildirim olarak basılması
            // BrevisNotificationListenerService / AiSummaryEngine tarafında yapılır.
            // Burada sadece tetikliyoruz ve state'i güncelliyoruz.
            onAiSummaryTriggered(session, isClosingSummary)

            synchronized(session) {
                if (isClosingSummary) {
                    session.resetToIdle() // ---> NORMAL DURUM'a dönüş
                } else {
                    session.pendingBuffer.clear() // sayaç/tampon sıfırlanır, filtreleme devam eder
                    session.state = ChatState.FILTERING
                }
            }
        }
    }

    /** Servis onDestroy'da çağrılmalı — tüm bekleyen job'ları temizler. */
    fun shutdown() {
        scope.cancel()
        sessions.clear()
    }

    companion object {
        private const val MAX_BUFFER_WHEN_AI_DISABLED = 200
    }
}
