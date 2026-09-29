import 'package:flutter/material.dart';
import '../state/theme_controller.dart';
import '../widgets/settings_tile.dart';

class AppearanceScreen extends StatelessWidget {
  const AppearanceScreen({super.key, required this.controller});
  final ThemeController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Görünüm')),
      body: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 16),
            children: [
              SettingsGroup(
                children: [
                  _ModeTile(
                    title: 'Sistemi izle',
                    subtitle: 'Cihazının genel temasına göre otomatik değişir',
                    icon: Icons.smartphone,
                    selected: controller.mode == ThemeMode.system,
                    onTap: () => controller.setMode(ThemeMode.system),
                  ),
                  _ModeTile(
                    title: 'Aydınlık',
                    icon: Icons.light_mode_outlined,
                    selected: controller.mode == ThemeMode.light,
                    onTap: () => controller.setMode(ThemeMode.light),
                  ),
                  _ModeTile(
                    title: 'Karanlık',
                    icon: Icons.dark_mode_outlined,
                    selected: controller.mode == ThemeMode.dark,
                    onTap: () => controller.setMode(ThemeMode.dark),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({
    required this.title,
    this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SettingsTile(
      title: title,
      subtitle: subtitle,
      leadingIcon: icon,
      trailing: selected
          ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary, size: 20)
          : null,
      onTap: onTap,
    );
  }
}
