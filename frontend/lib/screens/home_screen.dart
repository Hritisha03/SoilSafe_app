import 'package:flutter/material.dart';
import 'input_form_screen.dart';
import 'info_screen.dart';
import 'start_assessment_screen.dart';
import 'results_screen.dart';
import '../services/api_service.dart';
import '../widgets/custom_widgets.dart';
import '../theme/app_theme.dart';

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
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Gradient Hero Section
            GradientHeroSection(
              title: 'SoilSafe',
              subtitle: 'Soil Safety Checker - A rapid, location-based decision-support tool for disaster management',
              icon: Icons.park,
              onActionPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StartAssessmentScreen()),
              ),
            ),

            const SizedBox(height: 20),

            // Info Text
            Center(
              child: Column(
                children: [
                  Text(
                    'Takes under a minute • For guidance only',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Use this to prioritize inspections — not a substitute for on-site geotechnical assessment.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // Quick Test Button
            SecondaryButton(
              label: 'Test Backend Connection',
              icon: Icons.cloud_queue,
              onPressed: () async {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => Center(
                    child: CustomCard(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          Text(
                            'Connecting...',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                );

                final res = await ApiService.healthCheck();
                Navigator.of(context).pop();

                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(
                      res['ok'] ? '✓ Connection Successful' : '✗ Connection Failed',
                      style: TextStyle(
                        color: res['ok'] ? AppTheme.lowRiskGreen : AppTheme.highRiskRed,
                      ),
                    ),
                    content: Text(
                      res['ok']
                          ? 'Backend responded: ${res['body']}'
                          : 'Could not reach backend.\n\nDetails: ${res['body']}\n\nTip: use the correct API_BASE for your platform (see frontend/README.md).',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 16),

            // Info Button
            SecondaryButton(
              label: 'Learn More',
              icon: Icons.info_outline,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const InfoScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
