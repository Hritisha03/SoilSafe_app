import 'package:flutter/material.dart';
import 'input_form_screen.dart';
import '../services/api_service.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SoilSafe'),
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: Theme.of(context).primaryColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Theme.of(context).primaryColor,
                      child: const Icon(Icons.eco, color: Colors.white, size: 32),
                    ),
                    const SizedBox(height: 12),
                    Text('SoilSafe', style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 8),
                    Text(
                      'Post-flood soil risk assessment. Quickly evaluate if crop land is safe after flooding using a simple ML-powered classifier.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Primary action
            ElevatedButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InputFormScreen())),
              icon: const Icon(Icons.play_arrow),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12.0),
                child: Text('Start Assessment', style: TextStyle(fontSize: 16)),
              ),
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 12),

            // Secondary action
            OutlinedButton.icon(
              onPressed: () async {
                // show loading dialog
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => const Center(child: CircularProgressIndicator()),
                );

                final res = await ApiService.healthCheck();

                // close loading
                Navigator.of(context).pop();

                // show result
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(res['ok'] ? 'Backend reachable' : 'Connection failed'),
                    content: Text(res['ok'] ? 'Backend responded: ${res['body']}' : 'Could not reach backend. Details: ${res['body']}\n\nTip: use the correct API_BASE for your platform (see frontend/README.md).'),
                    actions: [
                      TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK')),
                    ],
                  ),
                );
              },
              icon: const Icon(Icons.sync),
              label: const Text('Test Backend Connection'),
            ),

            const SizedBox(height: 18),
            Center(child: Text('Backend: ${ApiService.baseUrl}', style: Theme.of(context).textTheme.bodySmall)),
          ],
        ),
      ),
    );
  }
}
