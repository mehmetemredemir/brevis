import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Bölüm başlığı — "AYARLAR" gibi ALL CAPS etiketlerden kaçınıyoruz,
/// normal cümle biçimi kullanıyoruz.
class SettingsSectionLabel extends StatelessWidget {
  const SettingsSectionLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(text, style: Theme.of(context).textTheme.labelLarge),
    );
  }
}

/// Düz, gölgesiz, hairline-bölücülü bir satır grubu (kart yerine).
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.hairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 16),
            children[i],
          ],
        ],
      ),
    );
  }
}

class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leadingIcon,
    this.trailing,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final IconData? leadingIcon;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: leadingIcon != null ? Icon(leadingIcon, size: 20) : null,
      title: Text(title, style: Theme.of(context).textTheme.titleMedium),
      subtitle: subtitle != null
          ? Text(subtitle!, style: Theme.of(context).textTheme.bodyMedium)
          : null,
      trailing: trailing ??
          (onTap != null
              ? Icon(Icons.chevron_right, color: AppPalette.of(context).inkMuted, size: 20)
              : null),
    );
  }
}

class SettingsSwitchTile extends StatelessWidget {
  const SettingsSwitchTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leadingIcon,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String? subtitle;
  final IconData? leadingIcon;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SettingsTile(
      title: title,
      subtitle: subtitle,
      leadingIcon: leadingIcon,
      trailing: Switch(value: value, onChanged: onChanged),
      onTap: () => onChanged(!value),
    );
  }
}
