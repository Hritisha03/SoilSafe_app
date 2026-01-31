import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soilsafe/screens/start_assessment_screen.dart';
import 'package:soilsafe/services/api_service.dart';
import 'package:soilsafe/models/prediction_result.dart';
import 'package:soilsafe/screens/results_screen.dart';

void main() {
  testWidgets('Start Assessment → Analyze → Results flow (mocked)', (WidgetTester tester) async {
    // Inject a fake API responder
    ApiService.predictByLocationFn = (double lat, double lon, {String? region}) async {
      return PredictionResult(
        risk: 'High',
        confidence: 0.87,
        explanation: 'Top factors: high clay content, recent heavy rainfall',
        recommendation: 'Inspect urgently and restrict access',
        featureImportances: [
          {'feature': 'clay_fraction', 'importance': 0.4},
          {'feature': 'flood_frequency', 'importance': 0.3},
        ],
        influencingFactors: ['High clay fraction', 'Frequent flooding'],
        inferredFeatures: {'region': 'Ganges Plains', 'soil_type': 'clayey'},
        disclaimer: 'For guidance only',
      );
    };

    // Build the Start Assessment screen with a test location provider
    await tester.pumpWidget(MaterialApp(home: StartAssessmentScreen(getLocation: () async => {'latitude': 25.6, 'longitude': 85.1})));

    // Verify CTA is present
    expect(find.text('Allow Location & Analyze'), findsOneWidget);

    // Tap CTA
    await tester.tap(find.text('Allow Location & Analyze'));
    await tester.pump(); // start loading

    // Wait for navigation to finish
    await tester.pumpAndSettle();

    // Expect Results screen to contain the mocked data
    expect(find.text('HIGH'), findsOneWidget);
    expect(find.text('Inspect urgently and restrict access'), findsOneWidget);
    expect(find.text('Ganges Plains'), findsOneWidget);
    expect(find.text('soil_type'), findsOneWidget);
    expect(find.text('clayey'), findsOneWidget);

    // Cleanup override
    ApiService.predictByLocationFn = null;
  });
}
