import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../services/api_service.dart';
import '../widgets/custom_widgets.dart';
import '../theme/app_theme.dart';
import 'results_screen.dart';

class StartAssessmentScreen extends StatefulWidget {
  final Future<Map<String, double>> Function()? getLocation;

  const StartAssessmentScreen({Key? key, this.getLocation}) : super(key: key);

  @override
  State<StartAssessmentScreen> createState() => _StartAssessmentScreenState();
}

class _StartAssessmentScreenState extends State<StartAssessmentScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  bool _showManualEntry = false;
  final _latController = TextEditingController();
  final _lonController = TextEditingController();
  final _placeNameController = TextEditingController();
  String _manualEntryMode = 'coordinates';
  late AnimationController _expandController;

  @override
  void initState() {
    super.initState();
    _expandController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _expandController.dispose();
    _latController.dispose();
    _lonController.dispose();
    _placeNameController.dispose();
    super.dispose();
  }

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
          _showErrorDialog(
            'Location Permission Required',
            'Location access is needed to assess soil safety for your area. Please enable location permission in settings.',
          );
          return;
        }
      }

      Map<String, double>? loc;
      if (widget.getLocation != null) {
        loc = await widget.getLocation!();
      } else {
        final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best);
        loc = {'latitude': pos.latitude, 'longitude': pos.longitude};
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
      setState(() => _isLoading = false);
      if (!mounted) return;
      _showErrorDialog('Assessment Error', e.toString());
    }
  }

  Future<void> _handleApproximate() async {
    setState(() => _isLoading = true);

    try {
      const defaultCoord = 20.5937;
      Map<String, double> loc = {'latitude': defaultCoord, 'longitude': defaultCoord};

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
      setState(() => _isLoading = false);
      if (!mounted) return;
      String message = e.toString();
      if (message.contains('Soil type')) {
        message = 'Missing soil type. Please enter soil conditions manually.';
      }
      _showErrorDialog('Approximate Location Error', message);
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
      setState(() => _isLoading = false);
      if (!mounted) return;
      _showErrorDialog('Manual Entry Error', e.toString());
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title, style: const TextStyle(color: AppTheme.highRiskRed)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Start Assessment'),
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Card
            CustomCard(
              backgroundColor: AppTheme.primaryGreen.withOpacity(0.08),
              border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.2), width: 1),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: const Icon(
                      Icons.location_on_outlined,
                      size: 40,
                      color: AppTheme.primaryGreen,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Start Soil Assessment',
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Provide your location to get personalized soil safety guidance',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Primary Location Button
            if (_isLoading)
              Center(
                child: Column(
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 12),
                    Text(
                      'Assessing soil safety...',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              PrimaryButton(
                label: 'Use My Current Location',
                icon: Icons.location_searching,
                onPressed: _handlePrimary,
              ),

              const SizedBox(height: 12),

              SecondaryButton(
                label: 'Use Approximate Location',
                icon: Icons.my_location,
                onPressed: _handleApproximate,
              ),
            ],

            const SizedBox(height: 24),

            // Manual Entry Section
            CustomCard(
              padding: const EdgeInsets.all(0),
              border: Border.all(color: AppTheme.dividerColor, width: 1),
              child: Column(
                children: [
                  // Expandable Header
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        setState(() => _showManualEntry = !_showManualEntry);
                        if (_showManualEntry) {
                          _expandController.forward();
                        } else {
                          _expandController.reverse();
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.edit_location_alt, color: AppTheme.primaryGreen),
                                const SizedBox(width: 12),
                                Text(
                                  'Manual Location Entry',
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                              ],
                            ),
                            RotationTransition(
                              turns: Tween(begin: 0.0, end: 0.5).animate(_expandController),
                              child: const Icon(Icons.expand_more, color: AppTheme.primaryGreen),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Expanded Content
                  AnimatedCrossFade(
                    firstChild: const SizedBox.shrink(),
                    secondChild: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Divider(height: 1),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Mode Toggle
                              Row(
                                children: [
                                  Expanded(
                                    child: SegmentedButton<String>(
                                      segments: const <ButtonSegment<String>>[
                                        ButtonSegment<String>(
                                          value: 'coordinates',
                                          label: Text('Coordinates'),
                                          icon: Icon(Icons.pin_drop),
                                        ),
                                        ButtonSegment<String>(
                                          value: 'place',
                                          label: Text('Place Name'),
                                          icon: Icon(Icons.place),
                                        ),
                                      ],
                                      selected: <String>{_manualEntryMode},
                                      onSelectionChanged: (Set<String> newSelection) {
                                        setState(() => _manualEntryMode = newSelection.first);
                                      },
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 16),

                              // Coordinates Input
                              if (_manualEntryMode == 'coordinates') ...[
                                TextField(
                                  controller: _latController,
                                  decoration: const InputDecoration(
                                    labelText: 'Latitude (-90 to 90)',
                                    prefixIcon: Icon(Icons.north_outlined),
                                  ),
                                  keyboardType: TextInputType.number,
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _lonController,
                                  decoration: const InputDecoration(
                                    labelText: 'Longitude (-180 to 180)',
                                    prefixIcon: Icon(Icons.east_outlined),
                                  ),
                                  keyboardType: TextInputType.number,
                                ),
                              ] else ...[
                                TextField(
                                  controller: _placeNameController,
                                  decoration: const InputDecoration(
                                    labelText: 'Place Name',
                                    prefixIcon: Icon(Icons.place),
                                    hintText: 'e.g., New York, Tokyo',
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Note: Place name search is not yet available',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppTheme.highRiskRed,
                                  ),
                                ),
                              ],

                              const SizedBox(height: 16),

                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _handleManualLocation,
                                  child: const Text('Analyze This Location'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    crossFadeState: _showManualEntry ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                    duration: const Duration(milliseconds: 300),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Info Message
            CustomCard(
              backgroundColor: AppTheme.veryLightGreen,
              border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.2), width: 1),
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppTheme.primaryGreen, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Your location is used only to provide regional guidance. You can use approximate coordinates.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}