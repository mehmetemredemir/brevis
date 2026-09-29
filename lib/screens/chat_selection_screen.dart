import 'package:flutter/material.dart';
import '../state/config_controller.dart';
import '../widgets/chip_list_editor.dart';
import '../widgets/settings_tile.dart';

class ChatSelectionScreen extends StatelessWidget {
  const ChatSelectionScreen({super.key, required this.controller});
  final ConfigController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('İzlenen sohbetler')),
      body: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final chats = controller.config.monitoredChats;
          final allChatsMode = chats.isEmpty;

          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 16),
            children: [
              SettingsGroup(
                children: [
                  SettingsSwitchTile(
                    title: 'Seçili uygulamalardaki tüm sohbetler',
                    subtitle: allChatsMode
                        ? 'Şu an açık — belirli sohbet eklemek için kapat'
                        : 'Kapalı — sadece aşağıdaki sohbetler izlenecek',
                    value: allChatsMode,
                    onChanged: (value) {
                      if (value) {
                        controller.update((c) => c.copyWith(monitoredChats: const []));
                      }
                      // "false" seçilirse hiçbir şey yapmıyoruz; kullanıcı aşağıya
                      // en az bir sohbet ekleyene kadar zaten "tüm sohbetler" geçerli kalır.
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Belirli sohbetleri izlemek için gruptaki veya kişideki görünen '
                  'ismi WhatsApp\'taki ile BİREBİR aynı yaz (büyük/küçük harf önemli değil).',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              const SizedBox(height: 4),
              ChipListEditor(
                items: chats,
                hintText: 'Örn. Aile Grubu',
                emptyStateText: 'Henüz belirli bir sohbet eklenmedi — tüm sohbetler izleniyor.',
                onChanged: (updated) {
                  controller.update((c) => c.copyWith(monitoredChats: updated));
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
