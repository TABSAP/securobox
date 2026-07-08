class VaultContext {
  VaultContext._();
  static final VaultContext instance = VaultContext._();

  bool _decoy = false;
  bool _modeChanged = false;

  bool get isDecoy => _decoy;

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

  String get libraryKey => _decoy ? decoyLibraryKey : 'videoLibrary';
  String get customCategoriesKey =>
      _decoy ? decoyCustomCategoriesKey : 'customCategories';
  String get categoriesConfigKey =>
      _decoy ? 'categoriesConfig_decoy' : 'categoriesConfig';
  String get downloadHistoryKey =>
      _decoy ? decoyDownloadHistoryKey : 'downloadHistory';

  String get masterKeyId =>
      _decoy ? 'vault_master_key_decoy_v1' : 'vault_master_key_v1';
  String get vaultDirName => _decoy ? 'vault_decoy' : 'vault';
  String get tempDirName => _decoy ? 'sp_decrypted_decoy' : 'sp_decrypted';

  static const String decoyLibraryKey = 'videoLibrary_decoy';
  static const String decoyCustomCategoriesKey = 'customCategories_decoy';
  static const String decoyDownloadHistoryKey = 'downloadHistory_decoy';
}
