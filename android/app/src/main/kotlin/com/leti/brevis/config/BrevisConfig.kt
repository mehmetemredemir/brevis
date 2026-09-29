package com.leti.brevis.config

import kotlinx.serialization.Serializable

/**
 * Kullanıcının Flutter arayüzünden belirlediği tüm davranış kurallarını taşır.
 *
 * Bu sınıf immutable'dır: her güncelleme yeni bir kopya üretir (config.copy(...)).
 * ConfigRepository, MethodChannel'dan gelen JSON'ı bu sınıfa parse eder ve
 * SessionManager her yeni bildirimde en güncel kopyayı okur.
 *
 * @Serializable: Flutter <-> Kotlin arasında JSON string olarak taşınabilmesi için gerekli.
 * Alan adları burada AYNEN Flutter tarafındaki Dart modeliyle (brevis_config.dart)
 * birebir eşleşmeli — biri değişirse diğeri de değişmeli.
 */
@Serializable
data class BrevisConfig(

    // --- HANGİ UYGULAMALAR ---
    // Paket adı listesi. Örn: "com.whatsapp", "com.whatsapp.w4b" (WhatsApp Business),
    // ileride Telegram/Instagram DM desteği eklenirse buraya eklenir.
    val monitoredPackages: Set<String> = setOf("com.whatsapp"),

    // --- HANGİ SOHBETLER ---
    // Sohbet/grup adı listesi (case-insensitive karşılaştırılır).
    // BOŞ SET = ilgili uygulamadaki TÜM sohbetler izlenir.
    // Kullanıcı örn. sadece "Aile Grubu" ve "İş" sohbetlerini seçtiyse bu set doldurulur.
    val monitoredChats: Set<String> = emptySet(),

    // --- NE ZAMAN ÇALIŞSIN (Aktiflik Takvimi) ---
    // null = 7/24 aktif. Dolu ise sadece bu pencere içinde filtreleme yapılır;
    // pencere dışında bildirimler normal şekilde geçer (Brevis devre dışı gibi davranır).
    val activeSchedule: ScheduleWindow? = null,

    // --- EŞİK DEĞERLERİ ---
    // Aynı sohbetten kısa sürede bu kadar mesaj gelirse FİLTRELEME moduna geçilir.
    val messageThresholdToFilter: Int = 6,

    // Filtreleme modunda biriken mesaj sayısı bu değere ulaşınca AI özeti tetiklenir.
    val aiSummaryThreshold: Int = 45,

    // "Kısa süre" tanımı: threshold'a ulaşmak için mesajların bu pencere içinde gelmesi gerekir.
    val burstWindowMillis: Long = 60_000L, // 1 dakika

    // Sessizlik/Cooldown süresi: bu süre boyunca yeni mesaj gelmezse "Kapanış Özeti" atılır
    // ve sohbet NORMAL duruma döner.
    val cooldownMillis: Long = 5 * 60_000L, // 5 dakika

    // --- ÖNCELİKLİ KELİME FİLTRESİ ---
    // Bu kelimelerden biri geçen mesaj, AI beklenmeden ANINDA orijinal haliyle iletilir.
    // Bu davranış aiEnabled'dan BAĞIMSIZDIR — AI kapalıyken de çalışır.
    val importantKeywords: Set<String> = emptySet(),

    // --- AI ÖZETİ İSTEĞE BAĞLI ---
    // true  -> eşiğe ulaşınca MediaPipe ile özet üretilir ve tek bir özet bildirimi atılır.
    // false -> AI hiç devreye girmez. Eşiğe (messageThresholdToFilter) ulaşan sohbetteki
    //          mesajlar sessizce gizlenmeye devam eder, HİÇBİR özet bildirimi atılmaz.
    //          Önemli kelime içeren mesajlar yine de anında gösterilir (yukarıdaki kural).
    val aiEnabled: Boolean = true,

    // --- GENEL AÇMA/KAPAMA ---
    val isEnabled: Boolean = true
) {
    fun isPackageMonitored(packageName: String): Boolean =
        isEnabled && monitoredPackages.contains(packageName)

    fun isChatMonitored(chatTitle: String?): Boolean {
        if (monitoredChats.isEmpty()) return true // boş = hepsi
        val title = chatTitle?.trim()?.lowercase() ?: return false
        return monitoredChats.any { it.trim().lowercase() == title }
    }

    fun containsImportantKeyword(text: String): Boolean {
        if (importantKeywords.isEmpty()) return false
        val lower = text.lowercase()
        return importantKeywords.any { lower.contains(it.trim().lowercase()) }
    }
}

/**
 * Haftanın belirli günlerinde, belirli saat aralığında aktiflik penceresi.
 * activeDays: Calendar.DAY_OF_WEEK değerleri (1=Pazar ... 7=Cumartesi).
 */
@Serializable
data class ScheduleWindow(
    val startHour: Int,
    val startMinute: Int,
    val endHour: Int,
    val endMinute: Int,
    val activeDays: Set<Int> = (1..7).toSet()
) {
    /** Gece yarısını aşan aralıkları da (örn. 23:00-07:00) doğru destekler. */
    fun isActiveNow(calendar: java.util.Calendar = java.util.Calendar.getInstance()): Boolean {
        val dayOfWeek = calendar.get(java.util.Calendar.DAY_OF_WEEK)
        if (dayOfWeek !in activeDays) return false

        val nowMinutes = calendar.get(java.util.Calendar.HOUR_OF_DAY) * 60 +
            calendar.get(java.util.Calendar.MINUTE)
        val startMinutes = startHour * 60 + startMinute
        val endMinutes = endHour * 60 + endMinute

        return if (startMinutes <= endMinutes) {
            nowMinutes in startMinutes until endMinutes
        } else {
            // Gece yarısını aşıyor, örn 23:00 -> 07:00
            nowMinutes >= startMinutes || nowMinutes < endMinutes
        }
    }
}
