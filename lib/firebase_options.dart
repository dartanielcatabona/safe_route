import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDummyKeyForWeb',
    appId: '1:123456789000:web:abcdef1234567890',
    messagingSenderId: '123456789000',
    projectId: 'saferoute-demo',
    authDomain: 'saferoute-demo.firebaseapp.com',
    storageBucket: 'saferoute-demo.appspot.com',
    measurementId: 'G-XXXXXXXXXX',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCl8rmuiDDYUVfA4fuWJy7jj4yzpP0q57c',
    appId: '1:681617768352:android:6643bc266ea04c466feec5',
    messagingSenderId: '681617768352',
    projectId: 'saferoute-5845d',
    storageBucket: 'saferoute-5845d.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDummyKeyForIOS',
    appId: '1:123456789000:ios:abcdef1234567890',
    messagingSenderId: '123456789000',
    projectId: 'saferoute-demo',
    storageBucket: 'saferoute-demo.appspot.com',
    iosBundleId: 'com.example.saferoute',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyDummyKeyForMacOS',
    appId: '1:123456789000:ios:abcdef1234567890',
    messagingSenderId: '123456789000',
    projectId: 'saferoute-demo',
    storageBucket: 'saferoute-demo.appspot.com',
    iosBundleId: 'com.example.saferoute',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyDummyKeyForWindows',
    appId: '1:123456789000:windows:abcdef1234567890',
    messagingSenderId: '123456789000',
    projectId: 'saferoute-demo',
    authDomain: 'saferoute-demo.firebaseapp.com',
    storageBucket: 'saferoute-demo.appspot.com',
    measurementId: 'G-XXXXXXXXXX',
  );
}
