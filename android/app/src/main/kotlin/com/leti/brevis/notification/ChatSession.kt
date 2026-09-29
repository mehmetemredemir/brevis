package com.leti.brevis.notification

/**
 * Sistem prompt'undaki 3 durumu birebir karşılar.
 */
enum class ChatState {
    IDLE,       // Normal Durum
    FILTERING,  // Filtre Aktif Durumu
    COOLDOWN    // Kapanış ve Sessizlik Durumu (FILTERING'in bir alt-fazı gibi davranır,
                // aşağıda açıklandığı gibi ayrı bir "durum" değil, bir zamanlayıcı sonucu)
}

/**
 * Tek bir mesajı (henüz özetlenmemiş, tamponda bekleyen) temsil eder.
 */
data class BufferedMessage(
    val sender: String,
    val text: String,
    val timestampMillis: Long
)

/**
 * chatKey = "<packageName>::<conversationTitle>" — her sohbet için benzersiz anahtar.
 *
 * Bu sınıfın bir örneği SessionManager'ın ConcurrentHashMap'inde tutulur.
 * Coroutine job referansları burada saklanır ki yeni mesaj geldiğinde
 * eski cooldown job'ı iptal edip yenisini kurabilelim (debounce).
 */
class ChatSession(
    val chatKey: String,
    val packageName: String,
    val conversationTitle: String
) {
    @Volatile var state: ChatState = ChatState.IDLE

    // Idle durumunda "burst" sayacı: kısa sürede kaç mesaj geldiğini sayar.
    var burstMessageCount: Int = 0
    var burstWindowStartMillis: Long = 0L

    // Filtering durumunda AI özetine kadar biriken mesajlar.
    val pendingBuffer: MutableList<BufferedMessage> = mutableListOf()

    // Şu an aktif olan cooldown coroutine job'ı (yeni mesajda iptal edilip yeniden kurulur).
    var cooldownJob: kotlinx.coroutines.Job? = null

    var lastMessageAtMillis: Long = 0L

    fun resetToIdle() {
        state = ChatState.IDLE
        burstMessageCount = 0
        burstWindowStartMillis = 0L
        pendingBuffer.clear()
        cooldownJob?.cancel()
        cooldownJob = null
    }
}
