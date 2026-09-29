import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class PermissionBanner extends StatelessWidget {
  const PermissionBanner({super.key, required this.onGrantPressed});
  final VoidCallback onGrantPressed;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.danger.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.notifications_off_outlined, color: palette.danger, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bildirim erişim izni gerekli',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: palette.danger),
                ),
                const SizedBox(height: 4),
                Text(
                  'Brevis, gelen mesajları görüp özetleyebilmek için sistem bildirim '
                  'erişimine ihtiyaç duyar. Bu izin olmadan hiçbir sohbet filtrelenmez.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: ElevatedButton(
                    onPressed: onGrantPressed,
                    child: const Text('İzin ver'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
