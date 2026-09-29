import 'package:flutter/material.dart';
import 'settings_tile.dart';
import '../theme/app_theme.dart';

/// Kullanıcının serbest metin girip liste halinde biriktirdiği değerler için
/// (sohbet adları, önemli kelimeler) ortak bileşen.
class ChipListEditor extends StatefulWidget {
  const ChipListEditor({
    super.key,
    required this.items,
    required this.onChanged,
    required this.hintText,
    required this.emptyStateText,
  });

  final List<String> items;
  final ValueChanged<List<String>> onChanged;
  final String hintText;
  final String emptyStateText;

  @override
  State<ChipListEditor> createState() => _ChipListEditorState();
}

class _ChipListEditorState extends State<ChipListEditor> {
  final _controller = TextEditingController();

  void _add() {
    final value = _controller.text.trim();
    if (value.isEmpty) return;
    if (widget.items.any((e) => e.toLowerCase() == value.toLowerCase())) {
      _controller.clear();
      return; // zaten var
    }
    widget.onChanged([...widget.items, value]);
    _controller.clear();
  }

  void _remove(String value) {
    widget.onChanged(widget.items.where((e) => e != value).toList());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: InputDecoration(hintText: widget.hintText),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _add(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _add,
                icon: const Icon(Icons.add),
                style: IconButton.styleFrom(
                  backgroundColor: palette.slate,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (widget.items.isEmpty)
            Text(widget.emptyStateText, style: Theme.of(context).textTheme.bodyMedium)
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.items
                  .map((item) => InputChip(
                        label: Text(item),
                        onDeleted: () => _remove(item),
                        deleteIcon: const Icon(Icons.close, size: 16),
                      ))
                  .toList(),
            ),
        ],
      ),
    );
  }
}
