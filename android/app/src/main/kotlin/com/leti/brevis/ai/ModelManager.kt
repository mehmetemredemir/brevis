package com.leti.brevis.ai

import android.content.Context
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import java.io.File
import java.io.FileOutputStream
import java.net.HttpURLConnection
import java.net.URL

/**
 * Gemma-2B (INT4, MediaPipe .bin formatı) modelinin tüm yaşam döngüsünü yönetir:
 * indirme + ilerleme takibi + silme. UI (Flutter) bu sınıfın durumuna
 * `state: StateFlow<ModelDownloadState>` üzerinden abone olur (bkz. MainActivity'deki
 * EventChannel köprüsü).
 *
 * MODEL_DOWNLOAD_URL nasıl doldurulur:
 * Gemma modelleri Kaggle Models üzerinde lisans kabulü gerektiren "gated" dosyalar,
 * yani uygulamanın kendi içinden doğrudan, kimlik doğrulamasız indirilebilecek bir
 * Google URL'i yok. Yapman gereken:
 *   1) kaggle.com/models/google/gemma'dan lisansı kabul edip gemma-2b-it-cpu-int4.bin'i
 *      (1.35 GB) manuel indir.
 *   2) Public GitHub reponun Releases sekmesinden bir release oluşturup dosyayı
 *      "Attach binaries" ile ekle (ücretsiz hesapta dosya başına 2 GB'a kadar destekleniyor).
 *   3) Oluşan direkt indirme linkini (github.com/<kullanici>/brevis/releases/download/...)
 *      aşağıdaki MODEL_DOWNLOAD_URL'e yapıştır. Repo public olduğu için bu link ekstra
 *      kimlik doğrulama gerektirmeden herkese açık çalışır.
 * Doldurulmadan "İndir" denenirse kullanıcıya anlamlı bir hata gösterilir (aşağı bakınız).
 */
class ModelManager private constructor(private val context: Context) {

    private val _state = MutableStateFlow(initialState())
    val state: StateFlow<ModelDownloadState> get() = _state

    // Kendi iç scope'unu yönetiyor ki kullanıcı ayarlar ekranından çıksa/uygulamayı
    // arka plana alsa bile indirme (process canlı kaldığı sürece) devam etsin.
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private var downloadJob: Job? = null

    private val modelDir: File get() = File(context.filesDir, "models")
    private val modelFile: File get() = File(modelDir, MODEL_FILE_NAME)
    private val partFile: File get() = File(modelDir, "$MODEL_FILE_NAME.part")

    private fun initialState(): ModelDownloadState =
        if (modelFile.exists() && modelFile.length() > 0) {
            ModelDownloadState(
                status = ModelStatus.READY,
                progressPercent = 100,
                downloadedBytes = modelFile.length(),
                totalBytes = modelFile.length()
            )
        } else {
            ModelDownloadState(status = ModelStatus.NOT_DOWNLOADED)
        }

    /** Model hazırsa mutlak dosya yolunu, değilse null döner. AiSummaryEngine bunu kullanır. */
    fun modelPathIfReady(): String? =
        if (_state.value.status == ModelStatus.READY) modelFile.absolutePath else null

    fun isReady(): Boolean = _state.value.status == ModelStatus.READY

    /**
     * İndirmeyi başlatır. Zaten indiriliyorsa veya hazırsa no-op.
     */
    fun startDownload() {
        if (_state.value.status == ModelStatus.DOWNLOADING || _state.value.status == ModelStatus.READY) return

        if (MODEL_DOWNLOAD_URL.isBlank()) {
            _state.value = ModelDownloadState(
                status = ModelStatus.ERROR,
                errorMessage = "Model indirme adresi henüz ayarlanmadı. " +
                    "ModelManager.kt içindeki MODEL_DOWNLOAD_URL'i doldurman gerekiyor."
            )
            return
        }

        downloadJob = scope.launch {
            var connection: HttpURLConnection? = null
            try {
                _state.value = ModelDownloadState(status = ModelStatus.DOWNLOADING)
                modelDir.mkdirs()

                connection = (URL(MODEL_DOWNLOAD_URL).openConnection() as HttpURLConnection).apply {
                    connectTimeout = 15_000
                    readTimeout = 15_000
                    connect()
                }

                if (connection.responseCode !in 200..299) {
                    throw java.io.IOException("Sunucu ${connection.responseCode} döndürdü")
                }

                val totalBytes = connection.contentLengthLong
                var downloaded = 0L
                val buffer = ByteArray(64 * 1024)

                connection.inputStream.use { input ->
                    FileOutputStream(partFile).use { output ->
                        while (isActive) {
                            val read = input.read(buffer)
                            if (read == -1) break
                            output.write(buffer, 0, read)
                            downloaded += read
                            val percent = if (totalBytes > 0) ((downloaded * 100) / totalBytes).toInt() else 0
                            // Her byte'ta değil, ~%1'lik adımlarda güncelle ki StateFlow'u boğmayalım.
                            if (percent != _state.value.progressPercent) {
                                _state.value = ModelDownloadState(
                                    status = ModelStatus.DOWNLOADING,
                                    progressPercent = percent,
                                    downloadedBytes = downloaded,
                                    totalBytes = totalBytes
                                )
                            }
                        }
                    }
                }

                if (!isActive) return@launch // iptal edildi, finally bloğu temizler

                partFile.renameTo(modelFile)
                _state.value = ModelDownloadState(
                    status = ModelStatus.READY,
                    progressPercent = 100,
                    downloadedBytes = modelFile.length(),
                    totalBytes = modelFile.length()
                )
            } catch (e: CancellationException) {
                partFile.delete()
                _state.value = ModelDownloadState(status = ModelStatus.NOT_DOWNLOADED)
                throw e
            } catch (e: Exception) {
                partFile.delete()
                _state.value = ModelDownloadState(
                    status = ModelStatus.ERROR,
                    errorMessage = e.message ?: "Bilinmeyen indirme hatası"
                )
            } finally {
                connection?.disconnect()
            }
        }
    }

    fun cancelDownload() {
        downloadJob?.cancel()
    }

    /** Kullanıcı "Modeli sil" butonuna bastığında çağrılır. AI toggle'dan BAĞIMSIZDIR. */
    fun deleteModel() {
        downloadJob?.cancel()
        modelFile.delete()
        partFile.delete()
        _state.value = ModelDownloadState(status = ModelStatus.NOT_DOWNLOADED)
    }

    companion object {
        private const val MODEL_FILE_NAME = "gemma2b_it_cpu_int4.bin"

        // Kaggle'dan indirdiğin gemma-2b-it-cpu-int4.bin dosyasını GitHub Releases'e
        // yükledikten sonra buraya GERÇEK linkini yapıştır. Format:
        // https://github.com/<kullanici-adin>/brevis/releases/download/<tag>/gemma-2b-it-cpu-int4.bin
        private const val MODEL_DOWNLOAD_URL = ""

        @Volatile private var instance: ModelManager? = null

        fun getInstance(context: Context): ModelManager =
            instance ?: synchronized(this) {
                instance ?: ModelManager(context.applicationContext).also { instance = it }
            }
    }
}
