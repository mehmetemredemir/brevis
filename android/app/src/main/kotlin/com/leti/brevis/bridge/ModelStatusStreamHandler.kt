package com.leti.brevis.bridge

import android.content.Context
import com.leti.brevis.ai.ModelManager
import io.flutter.plugin.common.EventChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

/**
 * `ModelManager.state` (StateFlow) her değiştiğinde Flutter tarafına JSON string olarak
 * akıtır. Flutter, indirme ilerleme çubuğunu polling YAPMADAN, gerçek zamanlı günceller.
 *
 * Kanal adı: "com.leti.brevis/modelStatus"
 */
class ModelStatusStreamHandler(private val context: Context) : EventChannel.StreamHandler {

    private val json = Json { ignoreUnknownKeys = true; encodeDefaults = true }
    private val scope = CoroutineScope(Dispatchers.Main)
    private var collectJob: Job? = null

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        val modelManager = ModelManager.getInstance(context)
        collectJob = scope.launch {
            modelManager.state.collect { state ->
                events.success(json.encodeToString(state))
            }
        }
    }

    override fun onCancel(arguments: Any?) {
        collectJob?.cancel()
        collectJob = null
    }

    companion object {
        const val CHANNEL_NAME = "com.leti.brevis/modelStatus"
    }
}
