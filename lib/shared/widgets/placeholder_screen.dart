import 'package:flutter/material.dart';

/// Temporary screen for routes that don't have a real UI yet. Every
/// GoRoute in the initial router setup points here until its feature
/// screen is built.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key, required this.routeName, this.params});

  final String routeName;
  final Map<String, String>? params;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(routeName)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              routeName,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            if (params != null && params!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(params.toString()),
            ],
          ],
        ),
      ),
    );
  }
}
