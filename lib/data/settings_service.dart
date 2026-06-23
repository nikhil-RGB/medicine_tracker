import 'package:shared_preferences/shared_preferences.dart';

/// Tiny boot flags only — never domain data (which lives in JSON files).
class SettingsService {
  SettingsService(this._prefs);
  final SharedPreferences _prefs;

  static Future<SettingsService> open() async =>
      SettingsService(await SharedPreferences.getInstance());

  static const _kOnboarding = 'onboardingComplete';
  static const _kDisclaimer = 'disclaimerAcceptedVersion';
  static const _kLastReconcile = 'lastReconcileEpoch';
  static const _kTzOverride = 'tzOverride';

  /// Bump to force the disclaimer to re-show if its legal text changes.
  static const int currentDisclaimerVersion = 1;

  bool get onboardingComplete => _prefs.getBool(_kOnboarding) ?? false;
  Future<void> setOnboardingComplete(bool v) => _prefs.setBool(_kOnboarding, v);

  int get disclaimerAcceptedVersion => _prefs.getInt(_kDisclaimer) ?? 0;
  bool get disclaimerAccepted => disclaimerAcceptedVersion >= currentDisclaimerVersion;
  Future<void> acceptDisclaimer() => _prefs.setInt(_kDisclaimer, currentDisclaimerVersion);
  Future<void> resetDisclaimer() => _prefs.setInt(_kDisclaimer, 0);

  int get lastReconcileEpoch => _prefs.getInt(_kLastReconcile) ?? 0;
  Future<void> setLastReconcileEpoch(int v) => _prefs.setInt(_kLastReconcile, v);

  String? get tzOverride => _prefs.getString(_kTzOverride);
}
