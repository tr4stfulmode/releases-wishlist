import 'package:app_wishlist/pages/LoginPage.dart';
import 'package:app_wishlist/pages/wishlist_page.dart';

class AppRoutes {
  static const String login = '/login';
  static const String wishlist = '/wishlist';
  static const String addWish = '/add-wish';

  static final routes = {
    login: (context) => const LoginPage(),
    wishlist: (context) => const WishlistPage(),
  };
}