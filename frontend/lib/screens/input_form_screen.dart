import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/api_service.dart';
import '../widgets/custom_widgets.dart';
import '../theme/app_theme.dart';
import 'results_screen.dart';

class InputFormScreen extends StatefulWidget {
  const InputFormScreen({Key? key}) : super(key: key);

  @override
  State<InputFormScreen> createState() => _InputFormScreenState();
}

class _InputFormScreenState extends State<InputFormScreen> {
  double? _latitude;
  double? _longitude;
  String? _region;
  bool _loading = false;
  bool _detectingLocation = false;
  bool _trackingLocation = false;
  StreamSubscription<Position>? _positionStreamSub;

  bool _isInIndia(double lat, double lon) {
    return lat >= 6.5 && lat <= 35.5 && lon >= 68.0 && lon <= 97.5;
  }

  Future<void> _onPosition(Position pos) async {
    final lat = pos.latitude;
    final lon = pos.longitude;

    if (!_isInIndia(lat, lon)) {
      await _positionStreamSub?.cancel();
      _positionStreamSub = null;
      setState(() {
        _trackingLocation = false;
        _latitude = lat;
        _longitude = lon;
      });
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Outside India'),
          content: const Text(
            'Detected location is outside India. This app is configured for India soil assessments.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            )
          ],
        ),
      );
      return;
    }

    setState(() {
      _latitude = lat;
      _longitude = lon;
    });

    try {
      final name = await ApiService.reverseGeocode(lat, lon);
      final mapped = _mapToFloodRegion(name);
      if (mapped != null) {
        setState(() => _region = mapped);
      } else if (name != null && _region == null) {
        setState(() => _region = name);
      }
    } catch (_) {}
  }

  String? _mapToFloodRegion(String? geocode) {
    if (geocode == null) return null;
    final g = geocode.toLowerCase();

    if (g.contains('assam') ||
        g.contains('brahmaputra') ||
        g.contains('guwahati') ||
        g.contains('dibrugarh')) return 'Brahmaputra Valley (Assam)';
    if (g.contains('kolkata') ||
        g.contains('west bengal') ||
        g.contains('sunderbans') ||
        g.contains('sundarban')) return 'West Bengal Coast';
    if (g.contains('andhra') ||
        g.contains('godavari') ||
        g.contains('visakhapatnam')) return 'Coastal Andhra & Godavari Basin';
    if (g.contains('odisha') ||
        g.contains('mahanadi') ||
        g.contains('bhubaneswar')) return 'Odisha Coast & Mahanadi';
    if (g.contains('kerala') ||
        g.contains('thiruvananthapuram') ||
        g.contains('kochi')) return 'Kerala (Monsoon-prone)';
    if (g.contains('bengal') ||
        g.contains('ganges') ||
        g.contains('ganga') ||
        g.contains('patna') ||
        g.contains('varanasi')) return 'Ganga Plains (UP/Bihar)';
    if (g.contains('gujarat') ||
        g.contains('kutch') ||
        g.contains('surat')) return 'Gujarat Coast';
    if (g.contains('maharashtra') ||
        g.contains('mumbai') ||
        g.contains('konkan')) return 'Konkan & Goa';
    if (g.contains('himachal') ||
        g.contains('uttarakhand') ||
        g.contains('shimla')) return 'Himachal / Uttarakhand (Hill floods)';
    if (g.contains('north') && g.contains('east')) return 'North-East Hill Flood Zones';

    if (g.contains('central') ||
        g.contains('madhya') ||
        g.contains('chhattisgarh')) return 'Central India Flood Plains';
    return null;
  }

  @override
  void dispose() {
    _positionStreamSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasLocation = _latitude != null && _longitude != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Location Assessment'),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Section
            GradientHeroSection(
              title: 'Locate & Assess',
              subtitle: 'Share your location for soil analysis',
              icon: Icons.location_on_outlined,
              actionLabel: hasLocation ? 'Update Location' : 'Use GPS',
              onActionPressed: _detectingLocation
                  ? () {}
                  : () async {
                      setState(() => _detectingLocation = true);
                      try {
                        bool serviceEnabled =
                            await Geolocator.isLocationServiceEnabled();
                        if (!serviceEnabled) {
                          throw Exception('Location services are disabled.');
                        }
                        LocationPermission permission =
                            await Geolocator.checkPermission();
                        if (permission == LocationPermission.denied) {
                          permission = await Geolocator.requestPermission();
                        }
                        if (permission == LocationPermission.denied ||
                            permission == LocationPermission.deniedForever) {
                          throw Exception('Location permission denied.');
                        }
                        final pos = await Geolocator.getCurrentPosition(
                          desiredAccuracy: LocationAccuracy.best,
                        );
                        _onPosition(pos);
                      } catch (e) {
                        if (!mounted) return;
                        showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Location Error'),
                            content: Text(e.toString()),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('OK'),
                              )
                            ],
                          ),
                        );
                      } finally {
                        setState(() => _detectingLocation = false);
                      }
                    },
            ),

            const SizedBox(height: 24),

            // Location Status Card
            if (hasLocation)
              CustomCard(
                backgroundColor: AppTheme.veryLightGreen,
                border: Border.all(
                  color: AppTheme.primaryGreen.withOpacity(0.2),
                  width: 1,
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: AppTheme.primaryGreen.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.all(8),
                          child: const Icon(
                            Icons.check_circle,
                            color: AppTheme.primaryGreen,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Location Detected',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Coordinates
                    Row(
                      children: [
                        const Icon(Icons.pin_drop, size: 18, color: Colors.grey),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Coordinates',
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                              Text(
                                '${_latitude!.toStringAsFixed(4)}, ${_longitude!.toStringAsFixed(4)}',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Region
                    if (_region != null)
                      Row(
                        children: [
                          const Icon(Icons.location_on, size: 18, color: Colors.grey),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Detected Region',
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                                Text(
                                  _region!,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              )
            else
              CustomCard(
                backgroundColor: AppTheme.dividerColor.withOpacity(0.3),
                border: Border.all(
                  color: AppTheme.dividerColor,
                  width: 1,
                ),
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.grey),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Location not detected yet',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 24),

            // Info Section
            CustomCard(
              backgroundColor: AppTheme.primaryGreen.withOpacity(0.05),
              border: Border.all(
                color: AppTheme.primaryGreen.withOpacity(0.1),
                width: 1,
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.help_outline, color: AppTheme.primaryGreen),
                      const SizedBox(width: 12),
                      Text(
                        'How it works',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'We collect your GPS location to provide regional soil safety guidance. Other soil parameters are inferred from regional datasets to maintain privacy.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Predictions are indicative and not a substitute for on-site testing.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Analyze Button
            if (_loading)
              Center(
                child: Column(
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 12),
                    Text(
                      'Analyzing soil conditions...',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              )
            else
              PrimaryButton(
                label: 'Analyze This Location',
                icon: Icons.search,
                onPressed: !hasLocation
                    ? null
                    : () {
                        setState(() => _loading = true);
                        _handleAnalyzeLocation();
                      },
              ),

            const SizedBox(height: 20),

            // Disclaimer
            CustomCard(
              backgroundColor: AppTheme.dividerColor.withOpacity(0.3),
              padding: const EdgeInsets.all(12),
              child: Text(
                'Data is processed securely and only used for assessment. Location data is not stored.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
            ),

            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Future<void> _handleAnalyzeLocation() async {
    try {
      final res = await ApiService.predictByLocation(
        _latitude!,
        _longitude!,
        region: _region,
      );
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ResultsScreen(result: res),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Network Error'),
          content: Text(
            'Could not reach the backend.\n\nDetails: $e',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            )
          ],
        ),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _loading = false);
    }
  }
}