import 'package:flutter/material.dart';
import 'input_form_screen.dart';
import '../services/api_service.dart';

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
            ),
            const SizedBox(height: 12),
            Center(child: Text('Backend: ${ApiService.baseUrl}', style: Theme.of(context).textTheme.bodySmall)),
            const SizedBox(height: 12),
            Center(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.sync),
                label: const Text('Test Connection'),
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}
