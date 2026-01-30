class InputData {
  String soilType;
  int floodFrequency;
  double rainfallIntensity;
  String elevationCategory;
  double? distanceFromRiver;
  double? latitude;
  double? longitude;
  String? region;

  InputData({
    required this.soilType,
    required this.floodFrequency,
    required this.rainfallIntensity,
    required this.elevationCategory,
    this.distanceFromRiver,
    this.latitude,
    this.longitude,
    this.region,
  });

  Map<String, dynamic> toJson() => {
        'soil_type': soilType,
        'flood_frequency': floodFrequency,
        'rainfall_intensity': rainfallIntensity,
        'elevation_category': elevationCategory,
        'distance_from_river': distanceFromRiver ?? 0.0,
        'latitude': latitude,
        'longitude': longitude,
        'region': region,
      };
}
