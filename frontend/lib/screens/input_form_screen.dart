import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/input_data.dart';
import '../services/api_service.dart';
import 'results_screen.dart';

class InputFormScreen extends StatefulWidget {
  const InputFormScreen({Key? key}) : super(key: key);

  @override
  State<InputFormScreen> createState() => _InputFormScreenState();
}

class _InputFormScreenState extends State<InputFormScreen> {
  final _formKey = GlobalKey<FormState>();
  String _soilType = 'clay';
  int _floodFreq = 1;
  double _rainfall = 50.0;
  String _elevation = 'low';
  double? _distance;

  // Location fields and flood-focused regions (India-only enforcement)
  double? _latitude;
  double? _longitude;
  String? _region;

  // Curated flood-oriented regions for India (demo purposes)
  static const List<String> floodRegions = [
    'Ganges-Brahmaputra Delta',
    'Brahmaputra Valley (Assam)',
    'Ganga Plains (UP/Bihar)',
    'West Bengal Coast',
    'Odisha Coast & Mahanadi',
    'Coastal Andhra & Godavari Basin',
    'Kerala (Monsoon-prone)',
    'Konkan & Goa',
    'Central India Flood Plains',
    'Maharashtra (Rivers & Coast)',
    'Gujarat Coast',
    'North-East Hill Flood Zones',
    'Himachal / Uttarakhand (Hill floods)'
  ];

  String? _selectedFloodRegion;

  bool _loading = false;
  bool _detectingLocation = false;
  bool _trackingLocation = false;
  StreamSubscription<Position>? _positionStreamSub;

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    final input = InputData(
        soilType: _soilType,
        floodFrequency: _floodFreq,
        rainfallIntensity: _rainfall,
        elevationCategory: _elevation,
        distanceFromRiver: _distance,
        latitude: _latitude,
        longitude: _longitude,
        region: _selectedFloodRegion);


    // Enforce India-only when a device location is present
    if (_latitude != null && _longitude != null && !_isInIndia(_latitude!, _longitude!)) {
      showDialog(context: context, builder: (_) => AlertDialog(title: const Text('Location outside India'), content: const Text('Detected location is outside India. Submission is restricted to India-only regions.'), actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))]));
      return;
    }

    // Require a flood-oriented region (India-only list)
    if (_selectedFloodRegion == null || _selectedFloodRegion!.isEmpty) {
      showDialog(context: context, builder: (_) => AlertDialog(title: const Text('Region required'), content: const Text('Please select a flood-oriented region in India before submitting.'), actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))]));
      return;
    }

    setState(() => _loading = true);
    try {
      final res = await ApiService.predict(input);
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => ResultsScreen(result: res)));
    } catch (e) {
      // Show a dialog with helpful troubleshooting steps for network/CORS issues
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Network Error'),
          content: Text(
              'Could not reach the backend at ${ApiService.baseUrl}.\n\nPlease make sure the backend is running (see backend/README).\nIf you are running the app on the web, use http://127.0.0.1:5000; on an Android emulator use http://10.0.2.2:5000.\n\nDetails: $e'),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK')),
          ],
        ),
      );
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  bool _isInIndia(double lat, double lon) {
    // India bounding box (approximate)
    return lat >= 6.5 && lat <= 35.5 && lon >= 68.0 && lon <= 97.5;
  }

  Future<void> _onPosition(Position pos) async {
    final lat = pos.latitude;
    final lon = pos.longitude;

    if (!_isInIndia(lat, lon)) {
      // Enforce India-only: stop tracking and inform user
      await _positionStreamSub?.cancel();
      _positionStreamSub = null;
      setState(() {
        _trackingLocation = false;
        _latitude = lat;
        _longitude = lon;
      });
      if (!mounted) return;
      showDialog(context: context, builder: (_) => AlertDialog(title: const Text('Outside India'), content: const Text('Detected location is outside India. This app is configured for India-only flood regions.'), actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))]));
      return;
    }

    setState(() {
      _latitude = lat;
      _longitude = lon;
    });

    // Try reverse geocoding and map to flood region
    try {
      final name = await ApiService.reverseGeocode(lat, lon);
      final mapped = _mapToFloodRegion(name);
      if (mapped != null) {
        setState(() => _selectedFloodRegion = mapped);
      } else if (name != null && _selectedFloodRegion == null) {
        // If reverse geocode returns a nearby place name, we set region as that name (best-effort)
        setState(() => _region = name);
      }
    } catch (e) {
      // ignore reverse geocode failures
    }
  }

  String? _mapToFloodRegion(String? geocode) {
    if (geocode == null) return null;
    final g = geocode.toLowerCase();
    // Keyword-based mapping (best-effort)
    if (g.contains('assam') || g.contains('brahmaputra') || g.contains('guwahati') || g.contains('dibrugarh')) return 'Brahmaputra Valley (Assam)';
    if (g.contains('kolkata') || g.contains('west bengal') || g.contains('sunderbans') || g.contains('sundarban')) return 'West Bengal Coast';
    if (g.contains('andhra') || g.contains('godavari') || g.contains('visakhapatnam')) return 'Coastal Andhra & Godavari Basin';
    if (g.contains('odisha') || g.contains('mahanadi') || g.contains('bhubaneswar')) return 'Odisha Coast & Mahanadi';
    if (g.contains('kerala') || g.contains('thiruvananthapuram') || g.contains('kochi')) return 'Kerala (Monsoon-prone)';
    if (g.contains('bengal') || g.contains('ganges') || g.contains('ganga') || g.contains('patna') || g.contains('varanasi')) return 'Ganga Plains (UP/Bihar)';
    if (g.contains('gujarat') || g.contains('kutch') || g.contains('surat')) return 'Gujarat Coast';
    if (g.contains('maharashtra') || g.contains('mumbai') || g.contains('konkan')) return 'Konkan & Goa';
    if (g.contains('himachal') || g.contains('uttarakhand') || g.contains('shimla')) return 'Himachal / Uttarakhand (Hill floods)';
    if (g.contains('north') && g.contains('east')) return 'North-East Hill Flood Zones';
    // fallback: central/other
    if (g.contains('central') || g.contains('madhya') || g.contains('chhattisgarh')) return 'Central India Flood Plains';
    return null;
  }

  @override
  void dispose() {
    _positionStreamSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Input Data')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              DropdownButtonFormField<String>(
                initialValue: _soilType,
                items: ['clay', 'silt', 'sand', 'loam'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => setState(() => _soilType = v ?? 'clay'),
                decoration: const InputDecoration(labelText: 'Soil type'),
              ),
              const SizedBox(height: 8),
              TextFormField(
                initialValue: _floodFreq.toString(),
                decoration: const InputDecoration(labelText: 'Flood frequency (times)'),
                keyboardType: TextInputType.number,
                validator: (v) => (v == null || v.isEmpty) ? 'Enter flood frequency' : null,
                onSaved: (v) => _floodFreq = int.tryParse(v ?? '1') ?? 1,
              ),
              const SizedBox(height: 8),
              Slider(
                value: _rainfall,
                min: 0,
                max: 400,
                divisions: 40,
                label: '${_rainfall.round()} mm',
                onChanged: (v) => setState(() => _rainfall = v),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _elevation,
                items: ['low', 'mid', 'high'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => setState(() => _elevation = v ?? 'low'),
                decoration: const InputDecoration(labelText: 'Elevation category'),
              ),
              const SizedBox(height: 8),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Distance from river (km) - optional'),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                onSaved: (v) => _distance = (v == null || v.isEmpty) ? null : double.tryParse(v),
              ),
              const SizedBox(height: 12),
              // Location controls
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.my_location),
                      label: const Text('Detect my location now'),
                      onPressed: () async {
                        setState(() => _detectingLocation = true);
                        try {
                          bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
                          if (!serviceEnabled) {
                            throw Exception('Location services are disabled.');
                          }
                          LocationPermission permission = await Geolocator.checkPermission();
                          if (permission == LocationPermission.denied) {
                            permission = await Geolocator.requestPermission();
                          }
                          if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
                            throw Exception('Location permission denied.');
                          }

                          final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best);
                          _onPosition(pos);
                        } catch (e) {
                          if (!mounted) return;
                          showDialog(context: context, builder: (_) => AlertDialog(title: const Text('Location error'), content: Text(e.toString()), actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))]));
                        } finally {
                          setState(() => _detectingLocation = false);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SwitchListTile(
                      title: const Text('Track my location'),
                      value: _trackingLocation,
                      onChanged: (v) async {
                        if (v) {
                          // start tracking
                          try {
                            bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
                            if (!serviceEnabled) throw Exception('Location services are disabled.');
                            LocationPermission permission = await Geolocator.checkPermission();
                            if (permission == LocationPermission.denied) {
                              permission = await Geolocator.requestPermission();
                            }
                            if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) throw Exception('Location permission denied.');

                            setState(() => _trackingLocation = true);
                            _positionStreamSub = Geolocator.getPositionStream(locationSettings: LocationSettings(accuracy: LocationAccuracy.best, distanceFilter: 50)).listen((pos) => _onPosition(pos));
                          } catch (e) {
                            setState(() => _trackingLocation = false);
                            if (!mounted) return;
                            showDialog(context: context, builder: (_) => AlertDialog(title: const Text('Location error'), content: Text(e.toString()), actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))]));
                          }
                        } else {
                          // stop tracking
                          await _positionStreamSub?.cancel();
                          _positionStreamSub = null;
                          setState(() => _trackingLocation = false);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(_latitude != null ? 'Lat: ${_latitude!.toStringAsFixed(4)}, Lon: ${_longitude!.toStringAsFixed(4)}' : 'No location detected', style: Theme.of(context).textTheme.bodySmall!, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              // Flood region selector (India-only)
              DropdownButtonFormField<String>(
                value: _selectedFloodRegion,
                items: floodRegions.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => setState(() => _selectedFloodRegion = v),
                decoration: const InputDecoration(labelText: 'Flood region (India) - required'),
                validator: (v) => (v == null || v.isEmpty) ? 'Select a flood-oriented region in India' : null,
                onSaved: (v) => _selectedFloodRegion = v,
              ),
              const SizedBox(height: 16),
              _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(onPressed: _submit, child: const Text('Submit'))
            ],
          ),
        ),
      ),
    );
  }
}
