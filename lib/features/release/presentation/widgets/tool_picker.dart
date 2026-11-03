import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../domain/release_tools.dart';
import 'rel_styles.dart';

/// 自分に合ったツールを選ぶ（言葉の組・1 語だけ・自分でつくったもの）。Luckarise 0.1.6 の ToolPickerDialog を移植。
class ToolPickerDialog extends StatefulWidget {
  const ToolPickerDialog({
    super.key,
    required this.tools,
    required this.selectedTool,
    required this.onSelect,
    required this.onDelete,
    required this.onCreate,
  });

  /// 選択肢。
  final List<ToolOption> tools;

  /// 選択中のツール id。
  final String selectedTool;

  /// ツールを選んだ（ダイアログは閉じる）。
  final ValueChanged<String> onSelect;

  /// 自分のツールを消す。消した後の選択肢と選択中の id を返す。
  final ({List<ToolOption> tools, String selected}) Function(String text) onDelete;

  /// 「＋ 自分でつくる」。追加できたら true（ダイアログを閉じる）。
  final Future<bool> Function() onCreate;

  @override
  State<ToolPickerDialog> createState() => _ToolPickerDialogState();
}

class _ToolPickerDialogState extends State<ToolPickerDialog> {
  late List<ToolOption> _tools = widget.tools;
  late String _selected = widget.selectedTool;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final p = RelPalette.of(context);
    var ownHeaderShown = false;
    final rows = <Widget>[];
    for (final tool in _tools) {
      if (tool.own && !ownHeaderShown) {
        ownHeaderShown = true;
        rows.add(Padding(
          padding: const EdgeInsets.only(top: AppSpacing.sm + 4, bottom: AppSpacing.xs),
          child: Text(l10n.rel_cleaning_tool_own_header, style: RelStyles.caption.copyWith(color: p.text)),
        ));
      }
      final String title;
      String? subtitle;
      if (tool.id == ReleaseTools.set) {
        title = l10n.rel_cleaning_tool_set;
        subtitle = tool.text;
      } else if (tool.own) {
        title = tool.text;
      } else {
        title = l10n.rel_cleaning_tool_only(tool.text);
      }
      rows.add(RadioListTile<String>(
        value: tool.id,
        groupValue: _selected,
        contentPadding: EdgeInsets.zero,
        title: Text(title, style: RelStyles.body.copyWith(color: p.text)),
        subtitle: subtitle == null ? null : Text(subtitle, style: RelStyles.caption.copyWith(color: p.subText)),
        onChanged: (id) {
          if (id != null) widget.onSelect(id);
        },
        secondary: tool.own
            ? IconButton(
                tooltip: l10n.rel_cleaning_tool_delete(tool.text),
                icon: const Icon(Icons.close),
                onPressed: () {
                  final next = widget.onDelete(tool.text);
                  setState(() {
                    _tools = next.tools;
                    _selected = next.selected;
                  });
                },
              )
            : null,
      ));
    }
    return AlertDialog(
      title: Text(l10n.rel_cleaning_tool_dialog_title, style: RelStyles.heading.copyWith(color: p.text, fontSize: 18)),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.rel_cleaning_tool_dialog_intro, style: RelStyles.caption.copyWith(color: p.subText)),
            const SizedBox(height: AppSpacing.sm),
            ...rows,
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: () async {
                final added = await widget.onCreate();
                if (added && context.mounted) Navigator.of(context).pop();
              },
              child: Text(l10n.rel_cleaning_tool_create),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.rel_cleaning_tool_close)),
      ],
    );
  }
}

/// 自分のツールをつくる（頭の中で何かを消すイメージができた言葉や動作を 1 行で）。
/// 保存を押すと入力（未正規化）を返す。キャンセルは null。
class ToolCreatorDialog extends StatefulWidget {
  const ToolCreatorDialog({super.key, required this.full});

  /// すでに上限（10 個）まである。
  final bool full;

  @override
  State<ToolCreatorDialog> createState() => _ToolCreatorDialogState();
}

class _ToolCreatorDialogState extends State<ToolCreatorDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final p = RelPalette.of(context);
    final canSave = _controller.text.trim().isNotEmpty && !widget.full;
    return AlertDialog(
      title: Text(l10n.rel_cleaning_tool_create_title, style: RelStyles.heading.copyWith(color: p.text, fontSize: 18)),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.rel_cleaning_tool_create_body, style: RelStyles.body.copyWith(color: p.text)),
            const SizedBox(height: AppSpacing.sm),
            Text(l10n.rel_cleaning_tool_create_examples, style: RelStyles.caption.copyWith(color: p.subText)),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _controller,
              maxLength: OwnTools.maxLength,
              maxLines: 1,
              onChanged: (v) {
                final cleaned = OwnTools.clip(v.replaceAll('\n', ' '));
                if (cleaned != v) {
                  _controller.value = TextEditingValue(
                    text: cleaned,
                    selection: TextSelection.collapsed(offset: cleaned.length),
                  );
                }
                setState(() {});
              },
              decoration: InputDecoration(labelText: l10n.rel_cleaning_tool_create_label(OwnTools.maxLength)),
            ),
            if (widget.full)
              Text(
                l10n.rel_cleaning_tool_create_full(OwnTools.maxTools),
                style: RelStyles.caption.copyWith(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.rel_cleaning_tool_cancel)),
        TextButton(
          onPressed: canSave ? () => Navigator.of(context).pop(_controller.text) : null,
          child: Text(l10n.rel_cleaning_tool_create_save),
        ),
      ],
    );
  }
}
