import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../config/oauth_config.dart';
import 'social_auth_platform_stub.dart'
    if (dart.library.io) 'social_auth_platform_io.dart' as platform;

/// Bridges platform account pickers. Configure OAuth clients before shipping.
class SocialAuthService {
  bool _googleInitialized = false;

  Future<void> _ensureGoogleInit() async {
    if (_googleInitialized) return;
    final id = OAuthConfig.googleServerClientId;
    await GoogleSignIn.instance.initialize(
      serverClientId: id.isEmpty ? null : id,
    );
    _googleInitialized = true;
  }

  /// Opens the native Google account sheet; returns `null` if the user cancels.
  Future<GoogleSignInAccount?> signInWithGoogle() async {
    await _ensureGoogleInit();
    try {
      return await GoogleSignIn.instance.authenticate(
        scopeHint: const <String>['email', 'openid'],
      );
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return null;
      }
      rethrow;
    }
  }

  /// Requests Apple credentials.
  ///
  /// iOS/macOS: enable the Sign In with Apple capability in Xcode for the Runner target.
  /// Android: set [OAuthConfig.appleServiceId] + [OAuthConfig.appleRedirectUri].
  Future<AuthorizationCredentialAppleID> signInWithAppleNative() async {
    if (kIsWeb) {
      throw UnsupportedError(
        'Sign in with Apple for web requires additional setup '
        '(client ID + redirect URI).',
      );
    }

    if (platform.platformIsDarwinMobile) {
      final available = await SignInWithApple.isAvailable();
      if (!available) {
        throw StateError('Sign in with Apple is not enabled for this bundle.');
      }
    }

    final serviceId = OAuthConfig.appleServiceId;
    final redirect = OAuthConfig.appleRedirectUri;

    if (platform.platformUsesAndroidAppleOAuth &&
        (serviceId.isEmpty || redirect.isEmpty)) {
      throw StateError(
        'Android Apple Sign-In needs APPLE_SERVICE_ID and APPLE_REDIRECT_URI '
        'dart-define values (matches Apple Developer portal).',
      );
    }

    return SignInWithApple.getAppleIDCredential(
      scopes: const [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      webAuthenticationOptions: platform.platformUsesAndroidAppleOAuth
          ? WebAuthenticationOptions(
              clientId: serviceId,
              redirectUri: Uri.parse(redirect),
            )
          : null,
    );
  }
}
