import 'package:flutter/material.dart';
import '../models/model_download_state.dart';
import '../state/config_controller.dart';
import '../state/model_controller.dart';
import '../widgets/settings_tile.dart';
import '../theme/app_theme.dart';

class ThresholdsScreen extends StatelessWidget {
  const ThresholdsScreen({
    super.key,
    required this.controller,
    required this.modelController,
  });

  final ConfigController controller;
  final ModelController modelController;

  Future<void> _onAiToggle(BuildContext context, bool value) async {
    if (!value) {
      // Kapatmak modeli SİLMEZ — sadece özet üretimini durdurur.
      controller.update((cur) => cur.copyWith(aiEnabled: false));
      return;
    }

    if (modelController.state.status == ModelStatus.ready) {
      controller.update((cur) => cur.copyWith(aiEnabled: true));
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Model indirilecek'),
        content: const Text(
          'AI özeti için cihazına yaklaşık 1.5 GB büyüklüğünde bir model indirilmesi '
          'gerekiyor. İndirme bir kere yapılır, sonrasında özetleme tamamen çevrimdışı '
          'çalışır. Wi-Fi kullanmanı öneririz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('İndir ve aç'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      controller.update((cur) => cur.copyWith(aiEnabled: true));
      modelController.startDownload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Eşik değerleri ve AI')),
      body: AnimatedBuilder(
        animation: Listenable.merge([controller, modelController]),
        builder: (context, _) {
          final c = controller.config;

          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 16),
            children: [
              SettingsGroup(
                children: [
                  SettingsSwitchTile(
                    title: 'AI özeti',
                    subtitle: c.aiEnabled
                        ? 'Açık — biriken mesajlar tek satırlık özetle bildirilir'
                        : 'Kapalı — mesajlar sadece sessize alınır, özet üretilmez',
                    value: c.aiEnabled,
                    onChanged: (value) => _onAiToggle(context, value),
                  ),
                ],
              ),
              const SettingsSectionLabel('AI modeli'),
              _ModelStatusCard(modelController: modelController),
              const SettingsSectionLabel('Filtrelemeye ne zaman başlasın'),
              _ThresholdTile(
                title: 'Mesaj sayısı eşiği',
                description:
                    'Aynı sohbetten kısa sürede bu kadar mesaj gelirse bildirimler '
                    'gizlenmeye başlar.',
                value: c.messageThresholdToFilter,
                min: 3,
                max: 15,
                suffix: 'mesaj',
                onChanged: (v) => controller.update(
                  (cur) => cur.copyWith(messageThresholdToFilter: v),
                ),
              ),
              _ThresholdTile(
                title: '"Kısa süre" penceresi',
                description: 'Yukarıdaki mesaj sayısının hangi süre içinde gelmesi gerektiği.',
                value: c.burstWindowMillis ~/ 1000,
                min: 15,
                max: 300,
                step: 15,
                suffix: 'saniye',
                onChanged: (v) => controller.update(
                  (cur) => cur.copyWith(burstWindowMillis: v * 1000),
                ),
              ),
              if (c.aiEnabled)
                _ThresholdTile(
                  title: 'AI özeti eşiği',
                  description: 'Biriken mesaj sayısı buraya ulaşınca AI özeti üretilir.',
                  value: c.aiSummaryThreshold,
                  min: 10,
                  max: 100,
                  step: 5,
                  suffix: 'mesaj',
                  onChanged: (v) => controller.update(
                    (cur) => cur.copyWith(aiSummaryThreshold: v),
                  ),
                ),
              _ThresholdTile(
                title: 'Sessizlik süresi',
                description: c.aiEnabled
                    ? 'Bu süre boyunca yeni mesaj gelmezse "Kapanış Özeti" atılır ve '
                        'sohbet normale döner.'
                    : 'Bu süre boyunca yeni mesaj gelmezse sohbet sessizce normale döner.',
                value: c.cooldownMillis ~/ 60000,
                min: 1,
                max: 30,
                suffix: 'dakika',
                onChanged: (v) => controller.update(
                  (cur) => cur.copyWith(cooldownMillis: v * 60000),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Model durumu + indir/iptal + AYRI "modeli sil" butonu.
/// Silme, AI toggle'dan bilinçli olarak bağımsızdır: kullanıcı AI'yı açık bırakıp
/// sadece diskteki modeli silebilir (bir dahaki özet denemesinde sessizce basit
/// bir bildirime düşer, servis tarafında zaten bu şekilde ele alınıyor).
class _ModelStatusCard extends StatelessWidget {
  const _ModelStatusCard({required this.modelController});
  final ModelController modelController;

  @override
  Widget build(BuildContext context) {
    final state = modelController.state;
    final palette = AppPalette.of(context);

    return SettingsGroup(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(_iconFor(state.status), size: 20, color: _colorFor(state.status, palette)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _statusLabel(state),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              if (state.status == ModelStatus.downloading) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: state.progressPercent / 100,
                    minHeight: 6,
                    backgroundColor: palette.hairline,
                    color: palette.slate,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${state.downloadedSizeLabel} / ${state.totalSizeLabel}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
              if (state.status == ModelStatus.error && state.errorMessage != null) ...[
                const SizedBox(height: 6),
                Text(
                  state.errorMessage!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: palette.danger),
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (state.status == ModelStatus.notDownloaded || state.status == ModelStatus.error)
                    ElevatedButton.icon(
                      onPressed: modelController.startDownload,
                      icon: const Icon(Icons.download, size: 18),
                      label: const Text('Modeli indir'),
                    ),
                  if (state.status == ModelStatus.downloading)
                    OutlinedButton.icon(
                      onPressed: modelController.cancelDownload,
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('İptal et'),
                    ),
                  if (state.status == ModelStatus.ready)
                    OutlinedButton.icon(
                      onPressed: () => _confirmDelete(context),
                      icon: Icon(Icons.delete_outline, size: 18, color: palette.danger),
                      label: Text('Modeli sil', style: TextStyle(color: palette.danger)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: palette.danger),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final palette = AppPalette.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Model silinsin mi?'),
        content: const Text(
          'Disk alanı boşalır. AI özeti açık kalsa bile, model tekrar indirilene kadar '
          'özetler üretilmez; bu süre boyunca sadece basit bir mesaj sayısı bildirimi atılır.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: palette.danger),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      modelController.deleteModel();
    }
  }

  String _statusLabel(ModelDownloadState state) {
    switch (state.status) {
      case ModelStatus.notDownloaded:
        return 'İndirilmedi';
      case ModelStatus.downloading:
        return 'İndiriliyor · %${state.progressPercent}';
      case ModelStatus.ready:
        return 'Hazır · ${state.downloadedSizeLabel}';
      case ModelStatus.error:
        return 'İndirme başarısız';
    }
  }

  IconData _iconFor(ModelStatus status) {
    switch (status) {
      case ModelStatus.notDownloaded:
        return Icons.cloud_outlined;
      case ModelStatus.downloading:
        return Icons.downloading;
      case ModelStatus.ready:
        return Icons.check_circle_outline;
      case ModelStatus.error:
        return Icons.error_outline;
    }
  }

  Color _colorFor(ModelStatus status, AppPalette palette) {
    switch (status) {
      case ModelStatus.ready:
        return palette.slate;
      case ModelStatus.error:
        return palette.danger;
      default:
        return palette.inkMuted;
    }
  }
}

class _ThresholdTile extends StatelessWidget {
  const _ThresholdTile({
    required this.title,
    required this.description,
    required this.value,
    required this.min,
    required this.max,
    required this.suffix,
    required this.onChanged,
    this.step = 1,
  });

  final String title;
  final String description;
  final int value;
  final int min;
  final int max;
  final int step;
  final String suffix;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return SettingsGroup(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(description, style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: palette.slate.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$value $suffix',
                  style: TextStyle(
                    color: palette.slateDeep,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
        Slider(
          value: value.toDouble(),
          min: min.toDouble(),
          max: max.toDouble(),
          divisions: ((max - min) / step).round(),
          activeColor: palette.slate,
          onChanged: (v) => onChanged((v / step).round() * step),
        ),
      ],
    );
  }
}
