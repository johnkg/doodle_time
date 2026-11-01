import 'package:flutter/material.dart';

/// The grown-ups menu (shown after the parental gate).
///
/// The switches change right away in the sheet and call back so the screen
/// can store the new value.
void showGrownUpsSheet(
  BuildContext context, {
  required bool unlockAll,
  required bool soundsOn,
  required VoidCallback onSavePicture,
  required ValueChanged<bool> onUnlockAllChanged,
  required ValueChanged<bool> onSoundsChanged,
}) {
  showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) {
      var unlockAllNow = unlockAll;
      var soundsOnNow = soundsOn;
      return StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.download),
                title: const Text('Save picture (web)'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  onSavePicture();
                },
              ),
              SwitchListTile(
                secondary: const Icon(Icons.lock_open),
                title: const Text('Unlock all lessons'),
                value: unlockAllNow,
                onChanged: (value) {
                  setSheetState(() => unlockAllNow = value);
                  onUnlockAllChanged(value);
                },
              ),
              SwitchListTile(
                secondary: const Icon(Icons.volume_up),
                title: const Text('Sounds and voice'),
                value: soundsOnNow,
                onChanged: (value) {
                  setSheetState(() => soundsOnNow = value);
                  onSoundsChanged(value);
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}
