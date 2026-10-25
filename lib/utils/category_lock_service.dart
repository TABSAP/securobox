import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player_app/utils/vault_context.dart';

/// Optional category gates that reuse SecuroBox's configured biometric/PIN.
/// Access is checked on every category entry rather than cached for a session.
class CategoryLockService {
  CategoryLockService._();
  static final instance = CategoryLockService._();

  String get _key => VaultContext.instance.isDecoy
      ? 'lockedCategories_decoy'
      : 'lockedCategories';

  Future<Set<String>> lockedKeys() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_key) ?? const []).toSet();
  }

  Future<bool> isLocked(String categoryKey) async =>
      (await lockedKeys()).contains(categoryKey.toLowerCase());

  Future<void> setLocked(String categoryKey, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    final keys = (prefs.getStringList(_key) ?? const <String>[]).toSet();
    final key = categoryKey.toLowerCase();
    if (value) {
      keys.add(key);
    } else {
      keys.remove(key);
    }
    await prefs.setStringList(_key, keys.toList());
  }
}
