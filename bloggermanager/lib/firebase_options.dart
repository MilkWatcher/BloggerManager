import 'package:firebase_core/firebase_core.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    return FirebaseOptions(
      apiKey: 'AIzaSyBtFttQJNFBBunDX2LuLavDfQluklAh7L0Y', 
      appId: '1:529491180100:web:8d2e744963673160b1da11', 
      messagingSenderId: "529491180100",
      measurementId: "G-F276Y3JF7H",
      projectId: 'bloggermanager-f1e21',
      authDomain: 'bloggermanager-f1e21.firebaseapp.com',
      storageBucket: 'bloggermanager-f1e21.firebasestorage.app',
    );
  }
}
