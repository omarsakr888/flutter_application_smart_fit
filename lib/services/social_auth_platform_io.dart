import 'dart:io' show Platform;

bool get platformIsDarwinMobile => Platform.isIOS;

bool get platformUsesAndroidAppleOAuth => Platform.isAndroid;
