package app.securobox.vault

/**
 * Disguise launcher entry. A thin subclass of [MainActivity] so this component
 * has a real backing class (required by its <activity> entry in
 * AndroidManifest.xml). Its own icon, label and theme — declared in the
 * manifest — provide the disguise; disguise_service enables exactly one of
 * these activities at a time.
 */
class UtilitiesActivity : MainActivity()
