import 'package:flutter/material.dart';
import '../state/config_controller.dart';
import '../widgets/chip_list_editor.dart';

class KeywordsScreen extends StatelessWidget {
  const KeywordsScreen({super.key, required this.controller});
  final ConfigController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Önemli kelimeler')),
      body: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 16),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Bu kelimelerden biri geçen bir mesaj geldiğinde, sohbet filtrelenmiş '
                  'olsa bile o mesaj beklenmeden ANINDA olduğu gibi bilekliğine iletilir. '
                  'Örn. "Acil", "Kargo", adın, ya da sık aradığın bir kişinin adı.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              const SizedBox(height: 4),
              ChipListEditor(
                items: controller.config.importantKeywords,
                hintText: 'Örn. Acil',
                emptyStateText: 'Henüz önemli kelime eklenmedi.',
                onChanged: (updated) {
                  controller.update((c) => c.copyWith(importantKeywords: updated));
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
