import 'package:flutter/material.dart';

class NavigationService {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  
  static Future<dynamic>? navigateTo(String routeName, {Object? arguments}) {
    return navigatorKey.currentState?.pushNamed(routeName, arguments: arguments);
  }
  
  static Future<dynamic>? navigateToRoute(Route route) {
    return navigatorKey.currentState?.push(route);
  }
  
  static void goBack() {
    return navigatorKey.currentState?.pop();
  }
  
  static BuildContext? get context => navigatorKey.currentContext;
}
