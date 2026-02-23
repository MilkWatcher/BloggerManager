import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
  show TargetPlatform, defaultTargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.windows:
        return windows;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for this platform. '
          'Run FlutterFire CLI to generate platform-specific options.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBtFttQJNFBBunDX2LuLavDfQluklAh7L0',
    appId: '1:529491180100:web:8d2e744963673160b1da11',
    messagingSenderId: '529491180100',
    projectId: 'bloggermanager-f1e21',
    authDomain: 'bloggermanager-f1e21.firebaseapp.com',
    storageBucket: 'bloggermanager-f1e21.firebasestorage.app',
    measurementId: 'G-F276Y3JF7H',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyBtFttQJNFBBunDX2LuLavDfQluklAh7L0',
    appId: '1:529491180100:web:8d2e744963673160b1da11',
    messagingSenderId: '529491180100',
    projectId: 'bloggermanager-f1e21',
    authDomain: 'bloggermanager-f1e21.firebaseapp.com',
    storageBucket: 'bloggermanager-f1e21.firebasestorage.app',
  );
}
