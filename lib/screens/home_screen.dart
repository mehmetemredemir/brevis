import 'package:flutter/material.dart';
import '../state/config_controller.dart';
import '../state/model_controller.dart';
import '../state/theme_controller.dart';
import '../widgets/permission_banner.dart';
import '../widgets/settings_tile.dart';
import 'app_selection_screen.dart';
import 'appearance_screen.dart';
import 'chat_selection_screen.dart';
import 'keywords_screen.dart';
import 'schedule_screen.dart';
import 'thresholds_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.controller,
    required this.modelController,
    required this.themeController,
  });
  final ConfigController controller;
  final ModelController modelController;
  final ThemeController themeController;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller.load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Kullanıcı "Bildirim Erişimi" ayarından dönünce izin durumunu tazele.
    if (state == AppLifecycleState.resumed) {
      widget.controller.refreshPermissionStatus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Brevis')),
      body: AnimatedBuilder(
        animation: Listenable.merge([widget.controller, widget.themeController]),
        builder: (context, _) {
          if (widget.controller.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          final c = widget.controller.config;
          final chatCount = c.monitoredChats.isEmpty ? 'Tümü' : '${c.monitoredChats.length} sohbet';
          final appCount = '${c.monitoredPackages.length} uygulama';
          final scheduleText = c.activeSchedule == null ? '7/24 aktif' : 'Belirli saatlerde';

          return ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              if (!widget.controller.notificationAccessGranted)
                PermissionBanner(
                  onGrantPressed: widget.controller.openNotificationAccessSettings,
                ),
              const SettingsSectionLabel('Genel'),
              SettingsGroup(
                children: [
                  SettingsSwitchTile(
                    title: 'Brevis aktif',
                    subtitle: c.isEnabled
                        ? 'Bildirimler kurallarına göre filtreleniyor'
                        : 'Kapalı — hiçbir bildirime dokunulmuyor',
                    leadingIcon: Icons.power_settings_new,
                    value: c.isEnabled,
                    onChanged: (value) =>
                        widget.controller.update((cur) => cur.copyWith(isEnabled: value)),
                  ),
                  SettingsTile(
                    title: 'Görünüm',
                    subtitle: _themeModeLabel(widget.themeController.mode),
                    leadingIcon: Icons.palette_outlined,
                    onTap: () =>
                        _push(context, AppearanceScreen(controller: widget.themeController)),
                  ),
                ],
              ),
              const SettingsSectionLabel('Kapsam'),
              SettingsGroup(
                children: [
                  SettingsTile(
                    title: 'İzlenen uygulamalar',
                    subtitle: appCount,
                    leadingIcon: Icons.apps,
                    onTap: () => _push(context, AppSelectionScreen(controller: widget.controller)),
                  ),
                  SettingsTile(
                    title: 'İzlenen sohbetler',
                    subtitle: chatCount,
                    leadingIcon: Icons.forum_outlined,
                    onTap: () => _push(context, ChatSelectionScreen(controller: widget.controller)),
                  ),
                  SettingsTile(
                    title: 'Ne zaman çalışsın',
                    subtitle: scheduleText,
                    leadingIcon: Icons.schedule_outlined,
                    onTap: () => _push(context, ScheduleScreen(controller: widget.controller)),
                  ),
                ],
              ),
              const SettingsSectionLabel('Davranış'),
              SettingsGroup(
                children: [
                  SettingsTile(
                    title: 'Önemli kelimeler',
                    subtitle: c.importantKeywords.isEmpty
                        ? 'Yok — hiçbir mesaj otomatik geçirilmiyor'
                        : '${c.importantKeywords.length} kelime',
                    leadingIcon: Icons.priority_high,
                    onTap: () => _push(context, KeywordsScreen(controller: widget.controller)),
                  ),
                  SettingsTile(
                    title: 'Eşik değerleri ve AI',
                    subtitle: c.aiEnabled ? 'AI özeti açık' : 'AI özeti kapalı',
                    leadingIcon: Icons.tune,
                    onTap: () => _push(
                      context,
                      ThresholdsScreen(
                        controller: widget.controller,
                        modelController: widget.modelController,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  String _themeModeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'Sistemi izliyor';
      case ThemeMode.light:
        return 'Aydınlık';
      case ThemeMode.dark:
        return 'Karanlık';
    }
  }
}
