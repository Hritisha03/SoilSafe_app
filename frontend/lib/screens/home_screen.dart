import 'package:flutter/material.dart';
import 'input_form_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SoilSafe')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('SoilSafe', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            const Text(
                'Assess post-flood soil risk quickly. Enter simple site data and get an easy-to-understand safety level (Low / Medium / High).'),
            const Spacer(),
            Center(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start Assessment'),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InputFormScreen())),
              ),
            )
          ],
        ),
      ),
    );
  }
}
