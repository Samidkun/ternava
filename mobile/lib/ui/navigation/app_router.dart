import 'package:flutter/material.dart';

import '../../core/api/generated/types.dart';

class AppRouter {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static Future<T?> open<T>(String screenId, {JsonObject? args}) async {
    return await navigatorKey.currentState?.pushNamed<T>(
      '/$screenId',
      arguments: args,
    );
  }

  static void replace(String screenId, {JsonObject? args}) {
    navigatorKey.currentState?.pushReplacementNamed(
      '/$screenId',
      arguments: args,
    );
  }

  static void back<T>([T? result]) {
    navigatorKey.currentState?.pop(result);
  }
}
