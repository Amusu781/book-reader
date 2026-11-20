import 'dart:async';
import 'package:flutter/material.dart';
import '../services/reader_theme.dart';

/// The reader settings sheet, shared by the text reader and the PDF
/// reader so the same gear icon does the same thing in both.
///
/// [onChanged] fires for every change (persist the settings and
/// rebuild there). [onLayoutChanged] fires when a font/line-height
/// slider is released — the text reader repaginates there, since the
/// page breaks depend on the font metrics. Font size and line height
/// have no effect on rendered PDF pages; brightness and night mode do.
Future<void> showReaderSettingsSheet({
  required BuildContext context,
  required ReaderSettings settings,
  required VoidCallback onChanged,
  required VoidCallback onLayoutChanged,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheetState) {
        void changed() {
          unawaited(settings.save());
          onChanged();
        }

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Page style',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: PageTheme.values.map((t) {
                  return ChoiceChip(
                    label: Text(t.label),
                    selected: settings.theme == t,
                    onSelected: (_) {
                      setSheetState(() => settings.theme = t);
                      changed();
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              Text(settings.theme.description),
              SwitchListTile(
                title: const Text('Night mode'),
                value: settings.nightMode,
                onChanged: (v) {
                  setSheetState(() => settings.nightMode = v);
                  changed();
                },
              ),
              Text('Font size: ${settings.fontSize.round()}'),
              Slider(
                min: 14,
                max: 26,
                divisions: 12,
                value: settings.fontSize,
                onChanged: (v) {
                  setSheetState(() => settings.fontSize = v);
                  changed();
                },
                onChangeEnd: (_) => onLayoutChanged(),
              ),
              Text('Line spacing: ${settings.lineHeight.toStringAsFixed(1)}'),
              Slider(
                min: 1.2,
                max: 2.0,
                divisions: 8,
                value: settings.lineHeight,
                onChanged: (v) {
                  setSheetState(() => settings.lineHeight = v);
                  changed();
                },
                onChangeEnd: (_) => onLayoutChanged(),
              ),
              Text(
                'Brightness dim: ${(settings.brightnessDim * 100).round()}%',
              ),
              Slider(
                min: 0,
                max: 0.5,
                value: settings.brightnessDim,
                onChanged: (v) {
                  setSheetState(() => settings.brightnessDim = v);
                  changed();
                },
              ),
            ],
          ),
        );
      },
    ),
  );
}
