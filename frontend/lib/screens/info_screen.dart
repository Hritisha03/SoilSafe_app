import 'package:flutter/material.dart';
import '../widgets/custom_widgets.dart';
import '../theme/app_theme.dart';

class InfoScreen extends StatelessWidget {
  const InfoScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('About SoilSafe'),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Hero Section
            CustomCard(
              backgroundColor: AppTheme.primaryGreen.withOpacity(0.08),
              border: Border.all(
                color: AppTheme.primaryGreen.withOpacity(0.2),
                width: 1,
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: const Icon(
                      Icons.info_outline,
                      size: 48,
                      color: AppTheme.primaryGreen,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'SoilSafe',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppTheme.primaryGreen,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Soil Safety Assessment Tool',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // Section 1: Why Soil Weakens
            InfoSection(
              icon: Icons.water_damage,
              title: 'Why Soil Weakens After Floods',
              content:
                  'Flooding saturates soils, reducing cohesion and causing erosion. This removes fine materials and increases the likelihood of slope failure, subsidence, and reduced load-bearing capacity in agricultural land and infrastructure.',
              backgroundColor: AppTheme.highRiskRed.withOpacity(0.05),
              borderColor: AppTheme.highRiskRed.withOpacity(0.2),
            ),

            const SizedBox(height: 16),

            // Section 2: ML Model
            InfoSection(
              icon: Icons.smart_toy,
              title: 'How the ML Model Works',
              content:
                  'SoilSafe uses a Random Forest model trained on soil type, flood frequency, rainfall intensity, elevation, and proximity to rivers. The model returns a risk level, confidence score, and influencing factors to support assessment decisions.',
              backgroundColor: AppTheme.primaryGreen.withOpacity(0.05),
              borderColor: AppTheme.primaryGreen.withOpacity(0.2),
            ),

            const SizedBox(height: 16),

            // Section 3: Limitations
            InfoSection(
              icon: Icons.warning_outlined,
              title: 'Limitations & Ethical Considerations',
              content:
                  'This tool provides decision support only and is not a substitute for on-site geotechnical inspection. Models may be inaccurate for novel conditions. Always combine results with expert judgment for safety-critical decisions.',
              backgroundColor: AppTheme.mediumRiskOrange.withOpacity(0.05),
              borderColor: AppTheme.mediumRiskOrange.withOpacity(0.2),
            ),

            const SizedBox(height: 16),

            // Section 4: Tips
            CustomCard(
              backgroundColor: AppTheme.lowRiskGreen.withOpacity(0.05),
              border: Border.all(
                color: AppTheme.lowRiskGreen.withOpacity(0.2),
                width: 1,
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: AppTheme.lowRiskGreen.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.all(8),
                        child: const Icon(
                          Icons.lightbulb_outline,
                          color: AppTheme.lowRiskGreen,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Tips for Safe Use',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...[
                    'Use for rapid triage to prioritize inspections',
                    'High risk or low confidence: arrange an inspection',
                    'Contribute survey data to improve the model over time',
                  ]
                      .asMap()
                      .entries
                      .map<Widget>((entry) {
                        final tip = entry.value;
                        final isLast = entry.key == 2;
                        return Column(
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 3),
                                  child: Container(
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      color: AppTheme.lowRiskGreen.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Icon(
                                      Icons.check,
                                      size: 14,
                                      color: AppTheme.lowRiskGreen,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      tip,
                                      style: Theme.of(context).textTheme.bodyMedium,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (!isLast) const SizedBox(height: 12),
                          ],
                        );
                      })
                      .toList(),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Data Privacy Section
            CustomCard(
              backgroundColor: Colors.blue.shade50,
              border: Border.all(
                color: Colors.blue.withOpacity(0.2),
                width: 1,
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.all(8),
                        child: const Icon(
                          Icons.privacy_tip_outlined,
                          color: Colors.blue,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Privacy & Data',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Your location data is processed securely. We do not store personal information unless explicitly provided for research purposes.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Close Button
            SecondaryButton(
              label: 'Close',
              icon: Icons.close,
              onPressed: () => Navigator.of(context).pop(),
            ),

            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}