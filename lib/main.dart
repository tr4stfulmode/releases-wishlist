import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'pages/LoginPage.dart';
import 'pages/wishlist_page.dart';
import 'services/notification_service.dart';
import 'services/rustore_update_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await NotificationService.initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My Wishlist',
      navigatorKey: RuStoreUpdateService.navigatorKey, // ✅ ИСПОЛЬЗУЕМ RuStore СЕРВИС
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'Poppins',
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // Запускаем проверку обновлений через RuStore
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Future.delayed(const Duration(seconds: 3), () {
              print('🚀 MAIN: Starting RuStore update check...');
              RuStoreUpdateService.checkForUpdate(); // ✅ RuStore ПРОВЕРКА
            });
          });

          if (snapshot.hasData && snapshot.data != null) {
            return const WishlistPage();
          }
          return const LoginPage();
        },
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}