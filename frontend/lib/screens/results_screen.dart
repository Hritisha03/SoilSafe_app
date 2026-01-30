import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/prediction_result.dart';

class ResultsScreen extends StatelessWidget {
  final PredictionResult result;
  const ResultsScreen({Key? key, required this.result}) : super(key: key);

  Color _colorForRisk(String r) {
    switch (r.toLowerCase()) {
      case 'high':
        return Colors.red.shade600;
      case 'medium':
        return Colors.orange.shade600;
      default:
        return Colors.green.shade700;
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
            child: Padding(
              padding: const EdgeInsets.all(18.0),
              child: Column(children: [
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  CircleAvatar(radius: 28, backgroundColor: color, child: Icon(icon, color: Colors.white, size: 32)),
                ]),
                const SizedBox(height: 12),
                Text(result.risk, style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: color)),
                const SizedBox(height: 8),
                if (result.region != null) Text('Region: ${result.region}', style: const TextStyle(color: Colors.black54)),
                if (result.location != null) Text('Location: ${result.location!['latitude']}, ${result.location!['longitude']}', style: const TextStyle(color: Colors.black54)),
              ]),
            ),
          ),

          const SizedBox(height: 16),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Explanation', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(result.explanation),
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
          ])
        ]),
      ),
    );
  }
}
