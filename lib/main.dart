import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/swipe/swipe_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // ProviderScope 必须在 runApp 外层,否则 ref 无处可挂
  runApp(const ProviderScope(child: SnapSwipeApp()));
}

class SnapSwipeApp extends StatelessWidget {
  const SnapSwipeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SnapSwipe',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF34C759),
          brightness: Brightness.light,
        ),
      ),
      home: const SwipePage(),
    );
  }
}
