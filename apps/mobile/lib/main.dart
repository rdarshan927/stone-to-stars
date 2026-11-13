import 'package:flutter/material.dart';

void main() {
  runApp(const StoneToStarsApp());
}

class StoneToStarsApp extends StatelessWidget {
  const StoneToStarsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stone to Stars',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Stone to Stars')),
    );
  }
}
