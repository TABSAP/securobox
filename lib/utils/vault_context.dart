/// Routes every vault read/write to either the real namespace or the decoy
/// (duress) namespace. Flipped only by the authentication router after a PIN
/// is verified. The flag lives in memory only — a fresh app launch always
/// starts in real mode and the lock screen re-decides.
class VaultContext {
  VaultContext._();
  static final VaultContext instance = VaultContext._();

  bool _decoy = false;
  bool _modeChanged = false;

  bool get isDecoy => _decoy;

  /// True if the mode flipped since the last [clearModeChanged]. The auth
  /// router uses this to decide whether the screen stack must be rebuilt
  /// (stale in-memory data from the other namespace).
  bool get modeChanged => _modeChanged;
  void clearModeChanged() => _modeChanged = false;

  void enterDecoy() {
    if (!_decoy) _modeChanged = true;
    _decoy = true;
  }

  void exitDecoy() {
    if (_decoy) _modeChanged = true;
    _decoy = false;
  }

  // ---- routed SharedPreferences keys ----
  String get libraryKey => _decoy ? decoyLibraryKey : 'videoLibrary';
  String get customCategoriesKey =>
      _decoy ? decoyCustomCategoriesKey : 'customCategories';
  String get downloadHistoryKey =>
      _decoy ? decoyDownloadHistoryKey : 'downloadHistory';

  // ---- routed crypto / filesystem ----
  String get masterKeyId =>
      _decoy ? 'vault_master_key_decoy_v1' : 'vault_master_key_v1';
  String get vaultDirName => _decoy ? 'vault_decoy' : 'vault';
  String get tempDirName => _decoy ? 'sp_decrypted_decoy' : 'sp_decrypted';

  // ---- decoy-namespace constants (for seeding, regardless of current mode) ----
  static const String decoyLibraryKey = 'videoLibrary_decoy';
  static const String decoyCustomCategoriesKey = 'customCategories_decoy';
  static const String decoyDownloadHistoryKey = 'downloadHistory_decoy';
}
