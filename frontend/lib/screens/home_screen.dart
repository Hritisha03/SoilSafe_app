import 'package:flutter/material.dart';
import 'input_form_screen.dart';
import 'info_screen.dart';
import 'start_assessment_screen.dart';
import 'results_screen.dart';
import '../services/api_service.dart';


class HomeScreen extends StatelessWidget {
  final Future<Map<String, double>> Function()? getLocation;

  const HomeScreen({Key? key, this.getLocation}) : super(key: key);

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
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 28.0, horizontal: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: const Color(0xFFA5D6A7),
                      child: Icon(Icons.park, color: Theme.of(context).colorScheme.primary, size: 34),
                    ),
                    const SizedBox(height: 14),
                    Text('SoilSafe', style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 6),
                    Text('Soil Safety Checker', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 10),
                    Text(
                      'A rapid, location-based decision-support tool for disaster management. Use this to prioritize inspections — not a substitute for on-site geotechnical assessment.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            ElevatedButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StartAssessmentScreen())),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 14.0),
                child: Text('Start Assessment', style: TextStyle(fontSize: 16)),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32), 
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),

            const SizedBox(height: 8),
            Center(child: Text('Takes under a minute • For guidance only', style: Theme.of(context).textTheme.bodySmall)),

            const SizedBox(height: 18),

            OutlinedButton.icon(
              onPressed: () async {
               
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => const Center(child: CircularProgressIndicator()),
                );

                final res = await ApiService.healthCheck();

               
                Navigator.of(context).pop();

                
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

            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InfoScreen())),
              icon: const Icon(Icons.info_outline),
              label: const Padding(padding: EdgeInsets.symmetric(vertical: 12.0), child: Text('Info', style: TextStyle(fontSize: 16))),
            ),

            const SizedBox(height: 18),
            Center(child: Text('Backend: ${ApiService.baseUrl}', style: Theme.of(context).textTheme.bodySmall)),
          ],
        ),
      ),
    );
  }
}