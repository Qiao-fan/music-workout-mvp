// File generated based on Firebase project: chopz-app
// Generated for: Android, iOS, Web

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
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
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
    apiKey: 'AIzaSyBRIEmbYGjmK4u7E36y3XqU7NxTdQke_Eg',
    appId: '1:20002844541:web:e12ce6cbabdf72029fe614',
    messagingSenderId: '20002844541',
    projectId: 'chopz-app',
    authDomain: 'chopz-app.firebaseapp.com',
    storageBucket: 'chopz-app.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCLYiZAhVVJ_mHuV5lYiNJFFBiSqLfXT-A',
    appId: '1:20002844541:android:9c8933fa68ca49149fe614',
    messagingSenderId: '20002844541',
    projectId: 'chopz-app',
    storageBucket: 'chopz-app.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAj1wwBN21oeagi4OEUn6pZx-DIypXsNu0',
    appId: '1:20002844541:ios:cb81a0c25d6016069fe614',
    messagingSenderId: '20002844541',
    projectId: 'chopz-app',
    storageBucket: 'chopz-app.firebasestorage.app',
    iosBundleId: 'com.chopz.musicWorkout',
  );
}
