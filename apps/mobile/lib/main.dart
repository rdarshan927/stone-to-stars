import 'package:flutter/material.dart';

import 'app/theme.dart';
import 'screens/dashboard_screen.dart';

void main() {
  runApp(const StoneToStarsApp());
}

class StoneToStarsApp extends StatelessWidget {
  const StoneToStarsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stone to Stars',
      theme: buildTheme(),
      home: const DashboardScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
