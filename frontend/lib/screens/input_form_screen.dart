import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/api_service.dart';
import 'results_screen.dart';

class InputFormScreen extends StatefulWidget {
  const InputFormScreen({Key? key}) : super(key: key);

  @override
  State<InputFormScreen> createState() => _InputFormScreenState();
}

class _InputFormScreenState extends State<InputFormScreen> {
  // We now accept only location (GPS) from the user. All other features are inferred server-side.
  double? _latitude;
  double? _longitude;
  String? _region;

  bool _loading = false;
  bool _detectingLocation = false;
  bool _trackingLocation = false;
  StreamSubscription<Position>? _positionStreamSub;



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
        setState(() => _region = mapped);
      } else if (name != null && _region == null) {
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
      appBar: AppBar(title: const Text('Assess my location')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: ListView(
          children: [
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 18.0, horizontal: 14.0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const Text('Location-based assessment', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text('Only your GPS location is required. We infer soil and flood parameters from regional data to provide a quick triage.', style: Theme.of(context).textTheme.bodyMedium),

                  const SizedBox(height: 12),

                  Row(children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: _detectingLocation ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.my_location),
                        label: Text(_detectingLocation ? 'Detecting...' : 'Detect my location'),
                        onPressed: _detectingLocation
                            ? null
                            : () async {
                                setState(() => _detectingLocation = true);
                                try {
                                  bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
                                  if (!serviceEnabled) throw Exception('Location services are disabled.');
                                  LocationPermission permission = await Geolocator.checkPermission();
                                  if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
                                  if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) throw Exception('Location permission denied.');
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
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.info_outline),
                        label: const Text('Why GPS only?'),
                        onPressed: () => showDialog(context: context, builder: (_) => AlertDialog(title: const Text('Why GPS only?'), content: const Text('For rapid post-flood triage we infer other parameters (rainfall, soil type) from regional datasets to minimize user burden. Predictions are indicative and not a substitute for on-site testing.'), actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))])),
                      ),
                    )
                  ]),

                  const SizedBox(height: 12),
                  Text(_latitude != null ? 'Lat: ${_latitude!.toStringAsFixed(4)}, Lon: ${_longitude!.toStringAsFixed(4)}' : 'No location detected', style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
                  if (_region != null) ...[
                    const SizedBox(height: 6),
                    Text('Detected place: $_region', style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
                  ],

                  const SizedBox(height: 16),
                  _loading
                      ? Column(children: const [CircularProgressIndicator(), SizedBox(height: 8), Text('Analyzing post-flood soil conditions...')])
                      : ElevatedButton.icon(
                          onPressed: () async {
                            if (_latitude == null || _longitude == null) {
                              showDialog(context: context, builder: (_) => AlertDialog(title: const Text('Location required'), content: const Text('Please detect your location first using the Detect button.'), actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))]));
                              return;
                            }

                            setState(() => _loading = true);
                            try {
                              // Optionally pass the detected region name to the backend if available
                              final res = await ApiService.predictByLocation(_latitude!, _longitude!, region: _region);
                              if (!mounted) return;
                              Navigator.push(context, MaterialPageRoute(builder: (_) => ResultsScreen(result: res)));
                            } catch (e) {
                              if (!mounted) return;
                              showDialog(context: context, builder: (context) => AlertDialog(title: const Text('Network Error'), content: Text('Could not reach the backend at ${ApiService.baseUrl}.\n\nDetails: $e'), actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))]));
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                            } finally {
                              setState(() => _loading = false);
                            }
                          },
                          icon: const Icon(Icons.search),
                          label: const Text('Analyze my location'),
                        )
                ]),
              ),
            ),

            const SizedBox(height: 12),
            const Text('Note: Predictions are indicative and based on regional data. Not a substitute for on-site testing.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.black54)),
          ],
        ),
      ),
    );
  }
}