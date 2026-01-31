import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/api_service.dart';
import 'results_screen.dart';

class StartAssessmentScreen extends StatefulWidget {
  // Optional test hook to bypass Geolocator in widget tests. Returns {'latitude':.., 'longitude':..}
  final Future<Map<String, double>> Function()? getLocation;

  const StartAssessmentScreen({Key? key, this.getLocation}) : super(key: key);

  @override
  State<StartAssessmentScreen> createState() => _StartAssessmentScreenState();
}

class _StartAssessmentScreenState extends State<StartAssessmentScreen> {
  bool _isLoading = false;

  Future<void> _handlePrimary() async {
    setState(() => _isLoading = true);

    try {
      // If a test hook is provided, skip permission checks to simplify tests
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

      // Get precise location (test hook or real geolocator)
      Map<String, double> loc;
      if (widget.getLocation != null) {
        loc = await widget.getLocation!();
      } else {
        final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best);
        loc = {'latitude': pos.latitude, 'longitude': pos.longitude};
      }

      final result = await ApiService.predictByLocation(loc['latitude']!, loc['longitude']!);

      if (!mounted) return;
      setState(() => _isLoading = false);

      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => ResultsScreen(result: result)));
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Analysis failed: $e')));
      }
    }
  }

  Future<void> _handleApproximate() async {
    setState(() => _isLoading = true);
    try {
      // If a test hook is provided, skip permission checks to simplify tests
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

      // Try last known position first or use test hook
      Map<String, double> loc;
      if (widget.getLocation != null) {
        loc = await widget.getLocation!();
      } else {
        Position? pos = await Geolocator.getLastKnownPosition();
        pos ??= await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.low);
        loc = {'latitude': pos.latitude, 'longitude': pos.longitude};
      }

      final result = await ApiService.predictByLocation(loc['latitude']!, loc['longitude']!);

      if (!mounted) return;
      setState(() => _isLoading = false);

      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => ResultsScreen(result: result)));
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Analysis failed: $e')));
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
                      'We use your location to assess post-flood soil safety in your area',
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
                    child: const Text('Allow Location & Analyze', style: TextStyle(fontSize: 16)),
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
            Center(child: Text('You will be asked to grant location permission. This app provides guidance only.', style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center)),
          ],
        ),
      ),
    );
  }
}
