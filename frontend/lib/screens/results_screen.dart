import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/prediction_result.dart';

class ResultsScreen extends StatelessWidget {
  final PredictionResult result;
  const ResultsScreen({Key? key, required this.result}) : super(key: key);

  Color _colorForRisk(String r) {
    switch (r.toLowerCase()) {
      case 'high':
        return const Color(0xFFC62828); 
      case 'medium':
        return const Color(0xFFF9A825); 
      default:
        return const Color(0xFF2E7D32); 
    }
  }

  IconData _iconForRisk(String r) {
    switch (r.toLowerCase()) {
      case 'high':
        return Icons.warning_amber_rounded;
      case 'medium':
        return Icons.report_problem_rounded;
      default:
        return Icons.check_circle_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorForRisk(result.risk);
    final icon = _iconForRisk(result.risk);

    Widget buildProbabilityBars() {
      if (result.probabilities == null) return const SizedBox.shrink();
      final entries = result.probabilities!.entries.toList()
        ..sort((a, b) => (b.value as num).compareTo(a.value as num));

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: entries.map((e) {
          final label = e.key;
          final val = (e.value as num).toDouble();
          Color barColor = Colors.grey;
          if (label.toLowerCase() == 'high') barColor = Colors.red.shade400;
          if (label.toLowerCase() == 'medium') barColor = Colors.orange.shade400;
          if (label.toLowerCase() == 'low') barColor = Colors.green.shade600;

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6.0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label), Text('${(val * 100).toStringAsFixed(1)}%')]),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(value: val, minHeight: 10, color: barColor, backgroundColor: barColor.withOpacity(0.2)),
              )
            ]),
          );
        }).toList(),
      );
    }

    String summaryText() {
      final sb = StringBuffer();
      sb.writeln('SoilSafe result: ${result.risk}');
      if (result.region != null) sb.writeln('Region: ${result.region}');
      if (result.location != null) sb.writeln('Location: ${result.location!['latitude']}, ${result.location!['longitude']}');
      sb.writeln('\n${result.explanation}');
      if (result.probabilities != null) {
        sb.writeln('\nProbabilities:');
        result.probabilities!.forEach((k, v) => sb.writeln('- $k: ${(((v as num) * 100).toStringAsFixed(1))}%'));
      }
      return sb.toString();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Assessment Result'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: color,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            color: color.withOpacity(0.08),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Container(decoration: BoxDecoration(color: color, shape: BoxShape.circle), padding: const EdgeInsets.all(12), child: Icon(icon, color: Colors.white, size: 28)),
                  const SizedBox(width: 14),
                  Expanded(child: Text(result.risk.toUpperCase(), style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: color))),
                  if (result.confidence != null) Text('${(result.confidence! * 100).toStringAsFixed(0)}%', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.black54)),
                ]),
                const SizedBox(height: 8),
                if (result.region != null || result.location != null)
                  Text('${result.region ?? ''}${result.region != null && result.location != null ? ' • ' : ''}${result.location != null ? '${result.location!['latitude'].toStringAsFixed(3)}, ${result.location!['longitude'].toStringAsFixed(3)}' : ''}', style: Theme.of(context).textTheme.bodySmall),
              ]),
            ),
          ),

          const SizedBox(height: 14),

         
          if (result.recommendation != null) Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [Icon(Icons.warning_amber_rounded, color: color), const SizedBox(width: 8), const Text('Safety recommendation', style: TextStyle(fontWeight: FontWeight.bold))]),
                const SizedBox(height: 8),
                Text(result.recommendation!, style: Theme.of(context).textTheme.bodyMedium),
              ]),
            ),
          ),

          const SizedBox(height: 12),


          if (result.influencingFactors != null && result.influencingFactors!.isNotEmpty) Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Influencing factors', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...result.influencingFactors!.map((f) => Padding(padding: const EdgeInsets.symmetric(vertical:4.0), child: Text('• $f'))).toList(),
              ]),
            ),
          ),

          const SizedBox(height: 12),


          if (result.featureImportances != null && result.featureImportances!.isNotEmpty) Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Feature importances', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...result.featureImportances!.map((fi) {
                  final feature = fi['feature'] ?? fi['name'] ?? fi.toString();
                  final imp = (fi['importance'] != null) ? (fi['importance'] as num).toDouble() : 0.0;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical:6.0),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(feature), Text('${(imp*100).toStringAsFixed(1)}%')]),
                      const SizedBox(height: 6),
                      ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: imp, minHeight: 8, color: Theme.of(context).colorScheme.primary, backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.18))),
                    ]),
                  );
                }).toList(),
              ]),
            ),
          ),

          const SizedBox(height: 12),

          if (result.inferredFeatures != null && result.inferredFeatures!.isNotEmpty) Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Inferred features (regional approximation)', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...result.inferredFeatures!.entries.map((e) => Padding(padding: const EdgeInsets.symmetric(vertical:4.0), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(e.key), Text(e.value.toString())]))).toList(),
              ]),
            ),
          ),

          const SizedBox(height: 16),

          if (result.probabilities != null) ...[
            const Text('Probabilities', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            buildProbabilityBars(),
            const SizedBox(height: 16),
          ],

          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: summaryText()));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Result copied to clipboard')));
                },
                icon: const Icon(Icons.copy),
                label: const Text('Copy Result'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.replay),
                label: const Text('Run another'),
              ),
            )
          ]),

          const SizedBox(height: 18),
          Text(result.disclaimer ?? 'Predictions are indicative and based on regional data', style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}