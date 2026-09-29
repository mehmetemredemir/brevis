import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/brevis_bridge.dart';
import '../state/config_controller.dart';
import '../theme/app_theme.dart';

class AppSelectionScreen extends StatefulWidget {
  const AppSelectionScreen({super.key, required this.controller});
  final ConfigController controller;

  @override
  State<AppSelectionScreen> createState() => _AppSelectionScreenState();
}

class _AppSelectionScreenState extends State<AppSelectionScreen> {
  List<InstalledApp>? _installedApps;
  String _query = '';

  @override
  void initState() {
    super.initState();
    BrevisBridge.instance.getInstalledApps().then((apps) {
      if (mounted) setState(() => _installedApps = apps);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('İzlenen uygulamalar')),
      body: AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) {
          final apps = _installedApps;
          if (apps == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (apps.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Cihazında hiç uygulama bulunamadı. Bu beklenmedik bir durum — '
                'uygulamayı yeniden başlatmayı deneyebilirsin.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            );
          }

          final selected = widget.controller.config.monitoredPackages.toSet();
          final filtered = _query.isEmpty
              ? apps
              : apps
                  .where((a) => a.label.toLowerCase().contains(_query.toLowerCase()))
                  .toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sadece mesajlaşma uygulamalarıyla sınırlı değilsin — bildirimleri '
                      'yoğun gelen herhangi bir uygulamayı işaretleyebilirsin. İşaretlemediğin '
                      'uygulamaların bildirimlerine hiç dokunulmaz.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      decoration: const InputDecoration(
                        hintText: 'Uygulama ara',
                        prefixIcon: Icon(Icons.search, size: 20),
                      ),
                      onChanged: (value) => setState(() => _query = value),
                    ),
                  ],
                ),
              ),
              if (selected.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${selected.length} uygulama seçili',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, indent: 60),
                  itemBuilder: (context, index) {
                    final app = filtered[index];
                    final isSelected = selected.contains(app.packageName);
                    return _AppRow(
                      app: app,
                      selected: isSelected,
                      onChanged: (value) {
                        widget.controller.update((c) {
                          final next = {...c.monitoredPackages};
                          if (value) {
                            next.add(app.packageName);
                          } else {
                            next.remove(app.packageName);
                          }
                          return c.copyWith(monitoredPackages: next.toList());
                        });
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Uygulama ikonu + isim + switch — ayrı bir satır bileşeni, çünkü bu ekranda
/// (diğer ayar ekranlarının aksine) her satırda gerçek bir uygulama ikonu var.
class _AppRow extends StatelessWidget {
  const _AppRow({required this.app, required this.selected, required this.onChanged});

  final InstalledApp app;
  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return ListTile(
      tileColor: palette.surface,
      onTap: () => onChanged(!selected),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: app.iconBase64 != null
            ? Image.memory(
                base64Decode(app.iconBase64!),
                width: 28,
                height: 28,
                gaplessPlayback: true,
              )
            : Container(
                width: 28,
                height: 28,
                color: palette.hairline,
                child: Icon(Icons.apps, size: 16, color: palette.inkMuted),
              ),
      ),
      title: Text(app.label, style: Theme.of(context).textTheme.titleMedium),
      trailing: Switch(value: selected, onChanged: onChanged),
    );
  }
}
