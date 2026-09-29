package com.leti.brevis.ai

import kotlinx.serialization.Serializable

enum class ModelStatus { NOT_DOWNLOADED, DOWNLOADING, READY, ERROR }

/**
 * Flutter'a olduğu gibi JSON olarak gönderilen anlık indirme durumu.
 * Dart tarafındaki `ModelDownloadStatus` ile alan adları birebir eşleşmeli.
 */
@Serializable
data class ModelDownloadState(
    val status: ModelStatus,
    val progressPercent: Int = 0,
    val downloadedBytes: Long = 0,
    val totalBytes: Long = 0,
    val errorMessage: String? = null
)
