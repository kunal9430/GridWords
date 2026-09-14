import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.grid_on, size: 64, color: Color(0xFF5B4FE9)),
                const SizedBox(height: 16),
                const Text(
                  'Grid Words',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text('Version 1.0.0', style: TextStyle(fontSize: 14, color: Colors.grey)),
                const SizedBox(height: 4),
                const Text('Developer: Kunal Kumar 😎', style: TextStyle(fontSize: 14, color: Colors.grey)),
                const SizedBox(height: 20),
                const Text(
                  'A customizable two-player word grid game featuring auto-calculated word lengths, '
                  'persistent letter and score palettes, and local state persistence.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, height: 1.5),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Back to Home'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
