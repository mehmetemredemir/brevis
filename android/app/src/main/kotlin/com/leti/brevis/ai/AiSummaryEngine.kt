package com.leti.brevis.ai

import android.content.Context
import com.google.mediapipe.tasks.genai.llminference.LlmInference
import com.google.mediapipe.tasks.genai.llminference.LlmInferenceSession
import com.leti.brevis.notification.BufferedMessage
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/**
 * MediaPipe LLM Inference API sarmalayıcısı. Model dosyası [ModelManager] tarafından
 * yönetilir; bu sınıf sadece "model hazırsa çalıştır" mantığını taşır.
 *
 * Tasarım notu: `LlmInference` örneğini (ağır, modeli belleğe yükler) tembel ve TEK SEFER
 * kuruyoruz; her özet isteğinde ise YENİ bir `LlmInferenceSession` açıp kapatıyoruz.
 * Böylece sohbetler arası bağlam sızmaz (her özet bağımsız bir "temiz" oturumdur) ama
 * modelin kendisi her seferinde yeniden yüklenmez — bu, pil/gecikme açısından kritik.
 */
class AiSummaryEngine private constructor(private val context: Context) {

    private val modelManager = ModelManager.getInstance(context)

    @Volatile private var llmInference: LlmInference? = null

    /**
     * @throws IllegalStateException model henüz indirilmediyse/hazır değilse.
     * @throws Exception MediaPipe çıkarımı başarısız olursa (bellek yetersizliği vb.).
     *   Çağıran taraf (BrevisNotificationListenerService) bunu fallback özetle karşılıyor,
     *   bu yüzden burada sessizce yutmuyoruz.
     */
    suspend fun summarize(chatTitle: String, messages: List<BufferedMessage>): String =
        withContext(Dispatchers.Default) {
            val modelPath = modelManager.modelPathIfReady()
                ?: throw IllegalStateException(
                    "AI modeli henüz indirilmedi. Ayarlar > Eşik değerleri ve AI'dan indirebilirsin."
                )

            val engine = getOrCreateEngine(modelPath)
            val prompt = buildPrompt(chatTitle, messages)

            val session = LlmInferenceSession.createFromOptions(
                engine,
                LlmInferenceSession.LlmInferenceSessionOptions.builder()
                    .setTopK(40)
                    .setTopP(0.9f)
                    .setTemperature(0.7f)
                    .build()
            )
            try {
                session.addQueryChunk(prompt)
                session.generateResponse().trim()
            } finally {
                session.close()
            }
        }

    /**
     * `LlmInference` örneği ağırdır (model dosyasını RAM'e yükler), bu yüzden tembel ve
     * senkronize kuruluyor. Model silinip yeniden indirilirse (kullanıcı "Modeli sil"
     * butonuna basıp tekrar indirirse) bu örnek [invalidate] ile temizlenmeli.
     */
    private fun getOrCreateEngine(modelPath: String): LlmInference {
        llmInference?.let { return it }
        synchronized(this) {
            llmInference?.let { return it }
            val options = LlmInference.LlmInferenceOptions.builder()
                .setModelPath(modelPath)
                .setMaxTokens(1024)
                .build()
            val created = LlmInference.createFromOptions(context, options)
            llmInference = created
            return created
        }
    }

    /** [ModelManager.deleteModel] çağrıldığında bellekteki motoru da temizlemek için. */
    fun invalidate() {
        synchronized(this) {
            llmInference?.close()
            llmInference = null
        }
    }

    private fun buildPrompt(chatTitle: String, messages: List<BufferedMessage>): String {
        val transcript = messages.joinToString("\n") { "${it.sender}: ${it.text}" }
        return """
            Aşağıda "$chatTitle" sohbetinden biriken mesajlar var.
            Bunları TEK CÜMLELİK, akıllı bileklikte okunacak kısalıkta bir özete indirge.
            Önemli isimleri ve varsa aksiyon gerektiren noktaları (buluşma, karar, soru) koru.
            Sadece özeti yaz, başka hiçbir şey ekleme.

            Mesajlar:
            $transcript

            Özet:
        """.trimIndent()
    }

    companion object {
        // Singleton: hem BrevisNotificationListenerService hem de (model silindiğinde
        // invalidate çağırması gereken) BrevisMethodChannelHandler AYNI örneği paylaşmalı,
        // aksi halde servis, silinmiş modeli belleğinde tutmaya devam edebilir.
        @Volatile private var instance: AiSummaryEngine? = null

        fun getInstance(context: Context): AiSummaryEngine =
            instance ?: synchronized(this) {
                instance ?: AiSummaryEngine(context.applicationContext).also { instance = it }
            }
    }
}
