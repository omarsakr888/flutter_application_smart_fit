/// Optional OAuth values (pass via `--dart-define=KEY=value` or configure native files).
///
/// Google (Android/iOS/Web): Prefer setting [googleServerClientId] to your OAuth 2.0
/// **Web client** ID when you want `idToken` validation on a backend. For native sign-in
/// only, you still need OAuth clients configured in Google Cloud Console and (iOS)
/// `GIDClientID` + URL scheme in [Info.plist](ios/Runner/Info.plist).
abstract final class OAuthConfig {
  static const googleServerClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue: '',
  );

  /// Apple Sign-In on Android uses a Services ID ("client id") plus redirect URI.
  static const appleServiceId = String.fromEnvironment(
    'APPLE_SERVICE_ID',
    defaultValue: '',
  );

  /// Must exactly match what you configured for the Apple Services ID redirect.
  static const appleRedirectUri = String.fromEnvironment(
    'APPLE_REDIRECT_URI',
    defaultValue: '',
  );
}
