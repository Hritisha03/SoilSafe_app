import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soilsafe/screens/start_assessment_screen.dart';
import 'package:soilsafe/services/api_service.dart';
import 'package:soilsafe/models/prediction_result.dart';
import 'package:soilsafe/screens/results_screen.dart';

void main() {
  testWidgets('Start Assessment → Analyze → Results flow (mocked)', (WidgetTester tester) async {

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

 
    await tester.pumpWidget(MaterialApp(home: StartAssessmentScreen(getLocation: () async => {'latitude': 25.6, 'longitude': 85.1})));


    expect(find.text('Allow Location & Analyze'), findsOneWidget);

   
    await tester.tap(find.text('Allow Location & Analyze'));
    await tester.pump(); 
    await tester.pumpAndSettle();

  
    expect(find.text('HIGH'), findsOneWidget);
    expect(find.text('Inspect urgently and restrict access'), findsOneWidget);
    expect(find.text('Ganges Plains'), findsOneWidget);
    expect(find.text('soil_type'), findsOneWidget);
    expect(find.text('clayey'), findsOneWidget);

   
    ApiService.predictByLocationFn = null;
  });
}
