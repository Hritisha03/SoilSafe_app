import 'package:flutter/material.dart';
import '../models/prediction_result.dart';

class ResultsScreen extends StatelessWidget {
  final PredictionResult result;
  const ResultsScreen({Key? key, required this.result}) : super(key: key);

  Color _colorForRisk(String r) {
    switch (r.toLowerCase()) {
      case 'high':
        return Colors.red.shade400;
      case 'medium':
        return Colors.orange.shade400;
      default:
        return Colors.green.shade600;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorForRisk(result.risk);
    return Scaffold(
      appBar: AppBar(title: const Text('Result')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
              child: Text(result.risk, style: const TextStyle(fontSize: 28, color: Colors.white)),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Explanation', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(result.explanation),
          if (result.probabilities != null) ...[
            const SizedBox(height: 12),
            const Text('Probabilities', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...result.probabilities!.entries.map((e) => Text('${e.key}: ${(e.value * 100).toStringAsFixed(1)}%'))
          ]
        ]),
      ),
    );
  }
}
