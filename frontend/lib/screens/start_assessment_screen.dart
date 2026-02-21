import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../services/api_service.dart';
import 'results_screen.dart';

class StartAssessmentScreen extends StatefulWidget {
 
  final Future<Map<String, double>> Function()? getLocation;

  const StartAssessmentScreen({Key? key, this.getLocation}) : super(key: key);

  @override
  State<StartAssessmentScreen> createState() => _StartAssessmentScreenState();
}

class _StartAssessmentScreenState extends State<StartAssessmentScreen> {
  bool _isLoading = false;
  bool _showManualEntry = false;
  final _latController = TextEditingController();
  final _lonController = TextEditingController();
  final _placeNameController = TextEditingController();
  String _manualEntryMode = 'coordinates'; 
  Future<void> _handlePrimary() async {
    setState(() => _isLoading = true);

    try {

      if (widget.getLocation == null) {
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
          setState(() => _isLoading = false);
          if (!mounted) return;
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Location permission required'),
              content: const Text('Location access is needed to assess soil safety for your area. Please enable location permission in settings.'),
              actions: [
                TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK')),
              ],
            ),
          );
          return;
        }
      }

      Map<String, double>? loc;
      if (widget.getLocation != null) {
        loc = await widget.getLocation!();
      } else {

        if (kIsWeb) {
          final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best);
          loc = {'latitude': pos.latitude, 'longitude': pos.longitude};
        } else {
          final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best);
          loc = {'latitude': pos.latitude, 'longitude': pos.longitude};
        }
      }

      if (loc == null) {
        throw Exception('Could not determine location. Please ensure location services are enabled.');
      }


      String? regionName;
      try {
        regionName = await ApiService.reverseGeocode(loc['latitude']!, loc['longitude']!);
      } catch (_) {
        regionName = null;
      }

      final result = await ApiService.predictByLocation(loc['latitude']!, loc['longitude']!, region: regionName);

      if (!mounted) return;
      setState(() => _isLoading = false);

      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => ResultsScreen(result: result)));
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);

        String message = 'Analysis failed: ${e.toString()}';
        if (e.toString().contains('Missing field')) {
          message = 'Analysis failed: Server rejected request (missing data). Server response: ${e.toString()}';
        } else if (e.toString().contains('Failed to call backend') || e.toString().contains('API error')) {
          message = 'Analysis failed: Could not contact backend or backend returned an error. Details: ${e.toString()}';
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    }
  }

  Future<void> _handleApproximate() async {
    setState(() => _isLoading = true);
    try {

      if (widget.getLocation == null) {
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
          setState(() => _isLoading = false);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location permission denied.')));
          return;
        }
      }

      Map<String, double>? loc;
      if (widget.getLocation != null) {
        loc = await widget.getLocation!();
      } else {

        if (kIsWeb) {
          final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.low);
          loc = {'latitude': pos.latitude, 'longitude': pos.longitude};
        } else {
          try {
            Position? pos = await Geolocator.getLastKnownPosition();
            pos ??= await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.low);
            loc = {'latitude': pos!.latitude, 'longitude': pos.longitude};
          } catch (e) {

            final pos2 = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.low);
            loc = {'latitude': pos2.latitude, 'longitude': pos2.longitude};
          }
        }
      }

      if (loc == null) throw Exception('Could not determine location for approximate assessment.');

      final result = await ApiService.predictByLocation(loc['latitude']!, loc['longitude']!);

      if (!mounted) return;
      setState(() => _isLoading = false);

      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => ResultsScreen(result: result)));
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        String message = 'Analysis failed: $e';
        if (e.toString().contains('UNSUPPORTED_OPERATION') || e.toString().contains('getLastKnownPosition')) {
          message = 'Analysis failed: Last known position is not available on this platform. Using current location failed as well.';
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    }
  }

  Future<void> _handleManualLocation() async {
    setState(() => _isLoading = true);
    try {
      double? lat, lon;

      if (_manualEntryMode == 'coordinates') {

        if (_latController.text.isEmpty || _lonController.text.isEmpty) {
          throw Exception('Please enter both latitude and longitude');
        }
        lat = double.tryParse(_latController.text);
        lon = double.tryParse(_lonController.text);
        if (lat == null || lon == null) {
          throw Exception('Latitude and longitude must be valid numbers');
        }
        if (lat < -90 || lat > 90 || lon < -180 || lon > 180) {
          throw Exception('Latitude must be -90 to 90, longitude must be -180 to 180');
        }
      } else {

        if (_placeNameController.text.isEmpty) {
          throw Exception('Please enter a place name or coordinates');
        }
 
        throw Exception('Place name search not yet available. Please use coordinates (latitude, longitude).');
      }

      if (lat == null || lon == null) {
        throw Exception('Could not parse location');
      }


      String? regionName;
      try {
        regionName = await ApiService.reverseGeocode(lat, lon);
      } catch (_) {
        regionName = null;
      }

      final result = await ApiService.predictByLocation(lat, lon, region: regionName);

      if (!mounted) return;
      setState(() => _isLoading = false);

      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => ResultsScreen(result: result)));
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        String message = 'Analysis failed: ${e.toString()}';
        if (e.toString().contains('Missing field')) {
          message = 'Analysis failed: Server rejected request (missing data). Details: ${e.toString()}';
        } else if (e.toString().contains('API error') || e.toString().contains('Failed to call backend')) {
          message = 'Analysis failed: Backend error. Details: ${e.toString()}';
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Start Soil Safety Assessment'),
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 28.0, horizontal: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(Icons.location_on_outlined, size: 56, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(height: 18),
                    Text('Start Soil Safety Assessment', style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    Text(
                      'We use your location to assess soil safety in your area',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Location will be used only to provide regional soil safety guidance. You can choose precise or approximate location.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: _handlePrimary,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14.0),
                    ),
                    child: const Text('Allow Location & Start Analysis', style: TextStyle(fontSize: 16)),
                  ),

            const SizedBox(height: 12),

            OutlinedButton(
              onPressed: _handleApproximate,
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12.0),
              ),
              child: const Text('Use approximate location'),
            ),

            const SizedBox(height: 16),


            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    InkWell(
                      onTap: () => setState(() => _showManualEntry = !_showManualEntry),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Check other areas',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            Icon(_showManualEntry ? Icons.expand_less : Icons.expand_more),
                          ],
                        ),
                      ),
                    ),
                    if (_showManualEntry) ...[
                      const SizedBox(height: 12),
                      Text('Enter coordinates for any location to check flood risk:', style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _latController,
                        keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Latitude (-90 to 90)',
                          hintText: '22.5726',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _lonController,
                        keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Longitude (-180 to 180)',
                          hintText: '88.3639',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _handleManualLocation,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1976D2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(vertical: 12.0),
                        ),
                        child: _isLoading ? const CircularProgressIndicator() : const Text('Analyze this location'),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),
            Center(child: Text('You will be asked to grant location permission. This app provides guidance only.', style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center)),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _latController.dispose();
    _lonController.dispose();
    _placeNameController.dispose();
    super.dispose();
  }
}