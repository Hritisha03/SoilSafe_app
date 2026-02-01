import 'package:flutter/material.dart';

class InfoScreen extends StatelessWidget {
  const InfoScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About SoilSafe')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Why soil weakens after floods', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text('Flooding saturates soils, reduces cohesion, causes erosion and removes fine material. This increases the likelihood of slope failure, subsidence and reduced load-bearing capacity in agricultural land and infrastructure.', style: Theme.of(context).textTheme.bodyMedium),

                const SizedBox(height: 14),
                Text('How the ML model works', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text('SoilSafe uses a Random Forest (interpretable tree-based model) trained on features like soil type, flood frequency, rainfall intensity, elevation and proximity to rivers. The model returns a risk label, confidence, and influencing factors to support triage decisions.', style: Theme.of(context).textTheme.bodyMedium),

                const SizedBox(height: 14),
                Text('Limitations and ethical disclaimer', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text('This tool provides decision support only. It is not a substitute for an on-site geotechnical inspection. Models may be inaccurate for novel conditions; always combine results with expert judgment for safety-critical decisions.', style: Theme.of(context).textTheme.bodyMedium),

                const SizedBox(height: 14),
                Text('Tips for safe use', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text('- Use for rapid triage to prioritize inspections.\n- High risk or low confidence → arrange an inspection.\n- Contribute high-quality survey data to improve the model over time.', style: Theme.of(context).textTheme.bodyMedium),

                const SizedBox(height: 18),
                Center(child: OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close'))),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}