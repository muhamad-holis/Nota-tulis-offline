import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../db/database_helper.dart';
import '../models/settings.dart';

class SettingsNotifier extends AsyncNotifier<Settings> {
  @override
  Future<Settings> build() async {
    return DatabaseHelper.instance.ensureSettingsExist();
  }

  Future<void> update(Map<String, dynamic> patch) async {
    final current = state.value;
    if (current?.id == null) return;
    await DatabaseHelper.instance.updateSettings(current!.id!, patch);
    state = AsyncData(await DatabaseHelper.instance.getSettings());
  }
}

final settingsProvider = AsyncNotifierProvider<SettingsNotifier, Settings>(
  SettingsNotifier.new,
);
