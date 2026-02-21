import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/prediction_result.dart';
import '../widgets/custom_widgets.dart';
import '../theme/app_theme.dart';

class ResultsScreen extends StatelessWidget {
  final PredictionResult result;
  const ResultsScreen({Key? key, required this.result}) : super(key: key);

  Color _colorForRisk(String r) {
    switch (r.toLowerCase()) {
      case 'high':
        return AppTheme.highRiskRed;
      case 'medium':
        return AppTheme.mediumRiskOrange;
      default:
        return AppTheme.lowRiskGreen;
    }
  }

  IconData _iconForRisk(String r) {
    switch (r.toLowerCase()) {
      case 'high':
        return Icons.warning_amber_rounded;
      case 'medium':
        return Icons.report_problem_rounded;
      default:
        return Icons.check_circle;
    }
  }

  String _summaryText() {
    final sb = StringBuffer();
    sb.writeln('SoilSafe Assessment Result: ${result.risk}');
    if (result.region != null) sb.writeln('Region: ${result.region}');
    if (result.location != null) sb.writeln('Location: ${result.location!['latitude']}, ${result.location!['longitude']}');
    if (result.confidence != null) sb.writeln('Confidence: ${(result.confidence! * 100).toStringAsFixed(0)}%');
    sb.writeln('\n${result.explanation}');
    if (result.recommendation != null) sb.writeln('\nRecommendation: ${result.recommendation}');
    if (result.probabilities != null) {
      sb.writeln('\nProbability Distribution:');
      result.probabilities!.forEach((k, v) => sb.writeln('- $k: ${(((v as num) * 100).toStringAsFixed(1))}%'));
    }
    return sb.toString();
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorForRisk(result.risk);
    final icon = _iconForRisk(result.risk);
    final confidence = result.confidence ?? 0.0;
    final hasFeatures = result.featureImportances != null && result.featureImportances!.isNotEmpty;
    final hasFactors = result.influencingFactors != null && result.influencingFactors!.isNotEmpty;
    final hasProbabilities = result.probabilities != null && result.probabilities!.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Assessment Result'),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Main Risk Card with Animation
            RiskCard(
              riskLevel: result.risk,
              confidence: confidence,
              explanation: result.explanation ?? 'Assessment complete',
            ),

            const SizedBox(height: 24),

            // Location & Region Info
            if (result.region != null || result.location != null)
              CustomCard(
                backgroundColor: AppTheme.veryLightGreen,
                border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.2), width: 1),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: AppTheme.primaryGreen, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Assessment Location',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (result.region != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          'Region: ${result.region}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    if (result.location != null)
                      Text(
                        'Coordinates: ${result.location!['latitude'].toStringAsFixed(4)}, ${result.location!['longitude'].toStringAsFixed(4)}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                  ],
                ),
              ),

            const SizedBox(height: 24),

            // Safety Recommendation
            if (result.recommendation != null)
              CustomCard(
                backgroundColor: color.withOpacity(0.08),
                border: Border.all(color: color.withOpacity(0.2), width: 1.5),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.all(8),
                          child: Icon(Icons.lightbulb_outline, color: color, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Safety Recommendation',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      result.recommendation!,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),

            if (result.recommendation != null) const SizedBox(height: 24),

            // Probability Distribution
            if (hasProbabilities) ...[
              SectionTitle(
                icon: Icons.pie_chart,
                title: 'Probability Distribution',
                subtitle: 'Likelihood of each risk category',
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  ...result.probabilities!.entries.map<Widget>((entry) {
                    Color probColor = AppTheme.primaryGreen;
                    final keyLower = entry.key.toLowerCase();
                    if (keyLower.contains('high')) {
                      probColor = AppTheme.highRiskRed;
                    } else if (keyLower.contains('medium')) {
                      probColor = AppTheme.mediumRiskOrange;
                    } else if (keyLower.contains('low')) {
                      probColor = AppTheme.lowRiskGreen;
                    }
                    
                    return ProbabilityCard(
                      label: entry.key,
                      value: (entry.value as num).toDouble().clamp(0.0, 1.0),
                      color: probColor,
                    );
                  }).toList(),
                ],
              ),
              const SizedBox(height: 24),
            ],

            // Feature Importance
            if (hasFeatures) ...[
              SectionTitle(
                icon: Icons.assessment,
                title: 'Feature Importance',
                subtitle: 'Key factors influencing this assessment',
              ),
              const SizedBox(height: 12),
              CustomCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ...result.featureImportances!.map<Widget>((fi) {
                      final feature = fi['feature'] ?? fi['name'] ?? 'Unknown';
                      final importance = (fi['importance'] != null)
                          ? (fi['importance'] as num).toDouble().clamp(0.0, 1.0)
                          : 0.0;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: FeatureImportanceBar(
                          featureName: feature.toString(),
                          importance: importance,
                          icon: _getFeatureIcon(feature.toString()),
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Influencing Factors
            if (hasFactors) ...[
              SectionTitle(
                icon: Icons.info_outline,
                title: 'Influencing Factors',
                subtitle: 'Conditions affecting the assessment',
              ),
              const SizedBox(height: 12),
              CustomCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...result.influencingFactors!.asMap().entries.map<Widget>((entry) {
                      final factor = entry.value;
                      final isLast = entry.key == result.influencingFactors!.length - 1;

                      return Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryGreen.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(
                                  Icons.check,
                                  color: AppTheme.primaryGreen,
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    factor,
                                    style: Theme.of(context).textTheme.bodyMedium,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (!isLast)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Divider(height: 1, color: AppTheme.dividerColor),
                            )
                          else
                            const SizedBox(height: 0),
                        ],
                      );
                    }).toList(),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Inferred Features (if available)
            if (result.inferredFeatures != null && result.inferredFeatures!.isNotEmpty) ...[
              SectionTitle(
                icon: Icons.auto_awesome,
                title: 'Regional Characteristics',
                subtitle: 'Inferred from location',
              ),
              const SizedBox(height: 12),
              CustomCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ...result.inferredFeatures!.entries.map<Widget>((entry) {
                      final isLast =
                          entry.key == result.inferredFeatures!.entries.last.key;

                      return Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                entry.key,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              Text(
                                entry.value.toString(),
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.primaryGreen,
                                ),
                              ),
                            ],
                          ),
                          if (!isLast)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Divider(height: 1, color: AppTheme.dividerColor),
                            ),
                        ],
                      );
                    }).toList(),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: SecondaryButton(
                    label: 'Copy Result',
                    icon: Icons.copy,
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _summaryText()));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Result copied to clipboard'),
                          backgroundColor: Colors.green.shade600,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: PrimaryButton(
                    label: 'New Assessment',
                    icon: Icons.refresh,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Disclaimer
            CustomCard(
              backgroundColor: AppTheme.dividerColor.withOpacity(0.3),
              padding: const EdgeInsets.all(12),
              child: Text(
                result.disclaimer ??
                    'These predictions are indicative and based on regional soil data. For critical decisions, consult with soil experts.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
            ),

            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  IconData _getFeatureIcon(String feature) {
    final lower = feature.toLowerCase();
    if (lower.contains('temp')) return Icons.thermostat;
    if (lower.contains('humid') || lower.contains('moisture')) return Icons.water_drop;
    if (lower.contains('ph')) return Icons.science;
    if (lower.contains('depth')) return Icons.layers;
    if (lower.contains('density')) return Icons.density_large;
    if (lower.contains('organic')) return Icons.eco;
    if (lower.contains('rain') || lower.contains('precip')) return Icons.cloud_queue;
    if (lower.contains('nitro')) return Icons.bubble_chart;
    return Icons.circle;
  }
}