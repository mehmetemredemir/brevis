import 'package:flutter/material.dart';
import '../models/brevis_config.dart';
import '../state/config_controller.dart';
import '../widgets/settings_tile.dart';
import '../theme/app_theme.dart';

const _dayLabels = {
  1: 'Paz',
  2: 'Pzt',
  3: 'Sal',
  4: 'Çar',
  5: 'Per',
  6: 'Cum',
  7: 'Cmt',
};

class ScheduleScreen extends StatelessWidget {
  const ScheduleScreen({super.key, required this.controller});
  final ConfigController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ne zaman çalışsın')),
      body: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final schedule = controller.config.activeSchedule;
          final scheduleEnabled = schedule != null;

          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 16),
            children: [
              SettingsGroup(
                children: [
                  SettingsSwitchTile(
                    title: 'Belirli saatlerde aktif',
                    subtitle: scheduleEnabled
                        ? 'Sadece aşağıdaki saat aralığında filtreleme yapılır'
                        : 'Kapalı — Brevis her zaman aktif (7/24)',
                    value: scheduleEnabled,
                    onChanged: (value) {
                      controller.update((c) => c.copyWith(
                            activeSchedule: () => value
                                ? const ScheduleWindow(
                                    startHour: 9,
                                    startMinute: 0,
                                    endHour: 22,
                                    endMinute: 0,
                                  )
                                : null,
                          ));
                    },
                  ),
                ],
              ),
              if (scheduleEnabled) ...[
                const SettingsSectionLabel('Saat aralığı'),
                SettingsGroup(
                  children: [
                    SettingsTile(
                      title: 'Başlangıç',
                      leadingIcon: Icons.wb_sunny_outlined,
                      trailing: Text(_formatTime(schedule.startHour, schedule.startMinute)),
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay(hour: schedule.startHour, minute: schedule.startMinute),
                        );
                        if (picked == null) return;
                        controller.update((c) => c.copyWith(
                              activeSchedule: () => ScheduleWindow(
                                startHour: picked.hour,
                                startMinute: picked.minute,
                                endHour: schedule.endHour,
                                endMinute: schedule.endMinute,
                                activeDays: schedule.activeDays,
                              ),
                            ));
                      },
                    ),
                    SettingsTile(
                      title: 'Bitiş',
                      leadingIcon: Icons.nightlight_outlined,
                      trailing: Text(_formatTime(schedule.endHour, schedule.endMinute)),
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay(hour: schedule.endHour, minute: schedule.endMinute),
                        );
                        if (picked == null) return;
                        controller.update((c) => c.copyWith(
                              activeSchedule: () => ScheduleWindow(
                                startHour: schedule.startHour,
                                startMinute: schedule.startMinute,
                                endHour: picked.hour,
                                endMinute: picked.minute,
                                activeDays: schedule.activeDays,
                              ),
                            ));
                      },
                    ),
                  ],
                ),
                const SettingsSectionLabel('Hangi günler'),
                Builder(builder: (context) {
                  final palette = AppPalette.of(context);
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _dayLabels.entries.map((entry) {
                        final isActive = schedule.activeDays.contains(entry.key);
                        return FilterChip(
                          label: Text(entry.value),
                          selected: isActive,
                          selectedColor: palette.slate.withValues(alpha: 0.18),
                          checkmarkColor: palette.slateDeep,
                          onSelected: (value) {
                            final nextDays = {...schedule.activeDays};
                            if (value) {
                              nextDays.add(entry.key);
                            } else if (nextDays.length > 1) {
                              // en az 1 gün seçili kalsın, tamamen boş takvim anlamsız
                              nextDays.remove(entry.key);
                            }
                            controller.update((c) => c.copyWith(
                                  activeSchedule: () => ScheduleWindow(
                                    startHour: schedule.startHour,
                                    startMinute: schedule.startMinute,
                                    endHour: schedule.endHour,
                                    endMinute: schedule.endMinute,
                                    activeDays: nextDays,
                                  ),
                                ));
                          },
                        );
                      }).toList(),
                    ),
                  );
                }),
                const SizedBox(height: 8),
              ],
            ],
          );
        },
      ),
    );
  }

  String _formatTime(int hour, int minute) =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}
