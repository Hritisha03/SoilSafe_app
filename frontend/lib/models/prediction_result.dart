class PredictionResult {
  final String risk;
  final double? confidence;
  final Map<String, dynamic>? probabilities;
  final String explanation;
  final String? recommendation;
  final List<dynamic>? featureImportances; // list of {feature, importance}
  final List<String>? influencingFactors;
  final String? region;
  final Map<String, dynamic>? location; // {'latitude':.., 'longitude':..}

  PredictionResult({required this.risk, this.confidence, this.probabilities, required this.explanation, this.recommendation, this.featureImportances, this.influencingFactors, this.region, this.location});

  factory PredictionResult.fromJson(Map<String, dynamic> json) {
    return PredictionResult(
      risk: json['risk_level'] ?? json['risk'] ?? 'Unknown',
      confidence: (json['confidence'] != null) ? (json['confidence'] as num).toDouble() : null,
      probabilities: json['probabilities'] != null ? Map<String, dynamic>.from(json['probabilities']) : null,
      explanation: json['explanation'] ?? '',
      recommendation: json['recommendation'],
      featureImportances: json['feature_importances'] != null ? List<dynamic>.from(json['feature_importances']) : null,
      influencingFactors: json['influencing_factors'] != null ? List<String>.from(json['influencing_factors'].map((e) => e.toString())) : null,
      region: json['region'],
      location: json['location'] != null ? Map<String, dynamic>.from(json['location']) : null,
    );
  }
}
