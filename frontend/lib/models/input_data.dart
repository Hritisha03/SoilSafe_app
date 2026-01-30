class InputData {
  String soilType;
  int floodFrequency;
  double rainfallIntensity;
  String elevationCategory;
  double? distanceFromRiver;

  InputData({
    required this.soilType,
    required this.floodFrequency,
    required this.rainfallIntensity,
    required this.elevationCategory,
    this.distanceFromRiver,
  });

  Map<String, dynamic> toJson() => {
        'soil_type': soilType,
        'flood_frequency': floodFrequency,
        'rainfall_intensity': rainfallIntensity,
        'elevation_category': elevationCategory,
        'distance_from_river': distanceFromRiver ?? 0.0,
      };
}
