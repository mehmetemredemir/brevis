/// Kotlin tarafındaki `com.leti.brevis.config.BrevisConfig` ile BİREBİR aynı
/// alan adlarını kullanır (kotlinx.serialization varsayılan olarak data class
/// property adlarını JSON key'i yapar). Biri değişirse diğeri de güncellenmeli.
library;

class BrevisConfig {
  final List<String> monitoredPackages;
  final List<String> monitoredChats;
  final ScheduleWindow? activeSchedule;
  final int messageThresholdToFilter;
  final int aiSummaryThreshold;
  final int burstWindowMillis;
  final int cooldownMillis;
  final List<String> importantKeywords;
  final bool aiEnabled;
  final bool isEnabled;

  const BrevisConfig({
    this.monitoredPackages = const ['com.whatsapp'],
    this.monitoredChats = const [],
    this.activeSchedule,
    this.messageThresholdToFilter = 6,
    this.aiSummaryThreshold = 45,
    this.burstWindowMillis = 60000,
    this.cooldownMillis = 300000,
    this.importantKeywords = const [],
    this.aiEnabled = true,
    this.isEnabled = true,
  });

  BrevisConfig copyWith({
    List<String>? monitoredPackages,
    List<String>? monitoredChats,
    ScheduleWindow? Function()? activeSchedule, // null döndürürse "takvimi kaldır" demek
    int? messageThresholdToFilter,
    int? aiSummaryThreshold,
    int? burstWindowMillis,
    int? cooldownMillis,
    List<String>? importantKeywords,
    bool? aiEnabled,
    bool? isEnabled,
  }) {
    return BrevisConfig(
      monitoredPackages: monitoredPackages ?? this.monitoredPackages,
      monitoredChats: monitoredChats ?? this.monitoredChats,
      activeSchedule:
          activeSchedule != null ? activeSchedule() : this.activeSchedule,
      messageThresholdToFilter:
          messageThresholdToFilter ?? this.messageThresholdToFilter,
      aiSummaryThreshold: aiSummaryThreshold ?? this.aiSummaryThreshold,
      burstWindowMillis: burstWindowMillis ?? this.burstWindowMillis,
      cooldownMillis: cooldownMillis ?? this.cooldownMillis,
      importantKeywords: importantKeywords ?? this.importantKeywords,
      aiEnabled: aiEnabled ?? this.aiEnabled,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }

  Map<String, dynamic> toJson() => {
        'monitoredPackages': monitoredPackages,
        'monitoredChats': monitoredChats,
        'activeSchedule': activeSchedule?.toJson(),
        'messageThresholdToFilter': messageThresholdToFilter,
        'aiSummaryThreshold': aiSummaryThreshold,
        'burstWindowMillis': burstWindowMillis,
        'cooldownMillis': cooldownMillis,
        'importantKeywords': importantKeywords,
        'aiEnabled': aiEnabled,
        'isEnabled': isEnabled,
      };

  factory BrevisConfig.fromJson(Map<String, dynamic> json) => BrevisConfig(
        monitoredPackages:
            List<String>.from(json['monitoredPackages'] ?? const ['com.whatsapp']),
        monitoredChats: List<String>.from(json['monitoredChats'] ?? const []),
        activeSchedule: json['activeSchedule'] != null
            ? ScheduleWindow.fromJson(json['activeSchedule'])
            : null,
        messageThresholdToFilter: json['messageThresholdToFilter'] ?? 6,
        aiSummaryThreshold: json['aiSummaryThreshold'] ?? 45,
        burstWindowMillis: json['burstWindowMillis'] ?? 60000,
        cooldownMillis: json['cooldownMillis'] ?? 300000,
        importantKeywords: List<String>.from(json['importantKeywords'] ?? const []),
        aiEnabled: json['aiEnabled'] ?? true,
        isEnabled: json['isEnabled'] ?? true,
      );
}

/// Kotlin `ScheduleWindow` ile birebir eşleşir.
/// activeDays: 1=Pazar ... 7=Cumartesi (java.util.Calendar.DAY_OF_WEEK ile aynı).
class ScheduleWindow {
  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;
  final Set<int> activeDays;

  const ScheduleWindow({
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
    this.activeDays = const {1, 2, 3, 4, 5, 6, 7},
  });

  Map<String, dynamic> toJson() => {
        'startHour': startHour,
        'startMinute': startMinute,
        'endHour': endHour,
        'endMinute': endMinute,
        'activeDays': activeDays.toList(),
      };

  factory ScheduleWindow.fromJson(Map<String, dynamic> json) => ScheduleWindow(
        startHour: json['startHour'],
        startMinute: json['startMinute'],
        endHour: json['endHour'],
        endMinute: json['endMinute'],
        activeDays: Set<int>.from(json['activeDays'] ?? const [1, 2, 3, 4, 5, 6, 7]),
      );
}
