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

    if (result.region != null) {
      sb.writeln('Region: ${result.region}');
    }

    if (result.location != null) {
      final lat = result.location!['latitude'];
      final lon = result.location!['longitude'];

      sb.writeln('Location: ${lat ?? 'N/A'}, ${lon ?? 'N/A'}');
    }

    if (result.confidence != null) {
      sb.writeln(
        'Confidence: ${(result.confidence! * 100).toStringAsFixed(0)}%',
      );
    }

    sb.writeln('\n${result.explanation}');

    if (result.recommendation != null) {
      sb.writeln('\nRecommendation: ${result.recommendation}');
    }

    if (result.probabilities != null) {
      sb.writeln('\nProbability Distribution:');

      result.probabilities!.forEach((k, v) {
        final value = (v is num) ? v.toDouble() : 0.0;
        sb.writeln('- $k: ${(value * 100).toStringAsFixed(1)}%');
      });
    }

    return sb.toString();
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorForRisk(result.risk);
    _iconForRisk(result.risk);
    final confidence = result.confidence ?? 0.0;

    final hasFeatures = result.featureImportances != null &&
        result.featureImportances!.isNotEmpty;

    final hasFactors = result.influencingFactors != null &&
        result.influencingFactors!.isNotEmpty;

    final hasProbabilities =
        result.probabilities != null && result.probabilities!.isNotEmpty;

    final lat = result.location?['latitude'];
    final lon = result.location?['longitude'];

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
            RiskCard(
              riskLevel: result.risk,
              confidence: confidence,
              explanation: result.explanation,
            ),
            const SizedBox(height: 24),
            if (result.region != null || result.location != null)
              CustomCard(
                backgroundColor: AppTheme.veryLightGreen,
                border: Border.all(
                    color: AppTheme.primaryGreen.withOpacity(0.2), width: 1),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.location_on,
                            color: AppTheme.primaryGreen, size: 20),
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
                        'Coordinates: ${lat is num ? lat.toStringAsFixed(4) : 'N/A'}, ${lon is num ? lon.toStringAsFixed(4) : 'N/A'}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 24),
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
                          child: Icon(Icons.lightbulb_outline,
                              color: color, size: 20),
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
            if (hasProbabilities) ...[
              const SectionTitle(
                icon: Icons.pie_chart,
                title: 'Probability Distribution',
                subtitle: 'Likelihood of each risk category',
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  ...result.probabilities!.entries.map<Widget>(
                    (entry) {
                      Color probColor = AppTheme.primaryGreen;

                      final keyLower = entry.key.toLowerCase();

                      if (keyLower.contains('high')) {
                        probColor = AppTheme.highRiskRed;
                      } else if (keyLower.contains('medium')) {
                        probColor = AppTheme.mediumRiskOrange;
                      } else if (keyLower.contains('low')) {
                        probColor = AppTheme.lowRiskGreen;
                      }

                      final value = (entry.value is num)
                          ? (entry.value as num).toDouble().clamp(0.0, 1.0)
                          : 0.0;

                      return ProbabilityCard(
                        label: entry.key,
                        value: value,
                        color: probColor,
                      );
                    },
                  ).toList(),
                ],
              ),
              const SizedBox(height: 24),
            ],
            if (hasFeatures) ...[
              const SectionTitle(
                icon: Icons.assessment,
                title: 'Feature Importance',
                subtitle: 'Key factors influencing this assessment',
              ),
              const SizedBox(height: 12),
              CustomCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    ...result.featureImportances!.map<Widget>((fi) {
                      final feature = fi['feature'] ?? fi['name'] ?? 'Unknown';

                      final importance = (fi['importance'] is num)
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
            if (hasFactors) ...[
              const SectionTitle(
                icon: Icons.info_outline,
                title: 'Influencing Factors',
                subtitle: 'Conditions affecting the assessment',
              ),
              const SizedBox(height: 12),
              CustomCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: result.influencingFactors!.map<Widget>((factor) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          const Icon(Icons.check, color: AppTheme.primaryGreen),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(factor),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 24),
            ],
            Row(
              children: [
                Expanded(
                  child: SecondaryButton(
                    label: 'Copy Result',
                    icon: Icons.copy,
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _summaryText()));

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Result copied'),
                          backgroundColor: Colors.green,
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
          ],
        ),
      ),
    );
  }

  IconData _getFeatureIcon(String feature) {
    final lower = feature.toLowerCase();

    if (lower.contains('temp')) return Icons.thermostat;
    if (lower.contains('humid') || lower.contains('moisture')) {
      return Icons.water_drop;
    }
    if (lower.contains('ph')) return Icons.science;
    if (lower.contains('depth')) return Icons.layers;
    if (lower.contains('density')) {
      return Icons.density_large;
    }
    if (lower.contains('organic')) return Icons.eco;
    if (lower.contains('rain') || lower.contains('precip')) {
      return Icons.cloud_queue;
    }
    if (lower.contains('nitro')) {
      return Icons.bubble_chart;
    }

    return Icons.circle;
  }
}
