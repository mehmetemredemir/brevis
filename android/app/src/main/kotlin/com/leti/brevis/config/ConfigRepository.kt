package com.leti.brevis.config

import android.content.Context
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.first
import kotlinx.serialization.decodeFromString
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

private val Context.dataStore by preferencesDataStore(name = "brevis_config")
private val CONFIG_KEY = stringPreferencesKey("config_json")

/**
 * Konfigürasyonun tek gerçek kaynağı (single source of truth).
 *
 * NotificationListenerService bu sınıfı Application seviyesinde singleton olarak
 * tutar ve her onNotificationPosted çağrısında `currentConfig` üzerinden en güncel
 * kuralları senkron, sıfır I/O maliyetiyle okur (StateFlow.value bellekte tutulur).
 *
 * Flutter -> Kotlin güncellemesi MethodChannel üzerinden JSON string olarak gelir,
 * burada parse edilip hem bellekteki StateFlow'a hem de DataStore'a (kalıcı, servis
 * yeniden başlasa bile hatırlanır) yazılır.
 */
class ConfigRepository(private val context: Context) {

    private val json = Json { ignoreUnknownKeys = true; encodeDefaults = true }

    private val _currentConfig = MutableStateFlow(BrevisConfig())
    val currentConfig: StateFlow<BrevisConfig> get() = _currentConfig

    /** Servis başlarken (onListenerConnected) diskten son bilinen config'i yükler. */
    suspend fun loadFromDisk() {
        val stored = context.dataStore.data.first()[CONFIG_KEY]
        if (stored != null) {
            runCatching { json.decodeFromString<BrevisConfig>(stored) }
                .onSuccess { _currentConfig.value = it }
        }
    }

    /** Flutter tarafından MethodChannel ile çağrılır: "updateConfig" */
    suspend fun updateConfig(rawJson: String) {
        val parsed = json.decodeFromString<BrevisConfig>(rawJson)
        _currentConfig.value = parsed
        context.dataStore.edit { prefs ->
            prefs[CONFIG_KEY] = json.encodeToString(parsed)
        }
    }

    /** Anlık, senkron okuma — bildirim işleme sırasında suspend'e girmemek için. */
    fun snapshot(): BrevisConfig = _currentConfig.value

    /** Flutter tarafından MethodChannel ile çağrılır: "getConfig" — ayarlar ekranı açılışında. */
    fun currentConfigJson(): String = json.encodeToString(_currentConfig.value)

    companion object {
        @Volatile private var instance: ConfigRepository? = null

        fun getInstance(context: Context): ConfigRepository =
            instance ?: synchronized(this) {
                instance ?: ConfigRepository(context.applicationContext).also { instance = it }
            }
    }
}
