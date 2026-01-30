import 'package:flutter/material.dart';
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

  bool _loading = false;

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    final input = InputData(
        soilType: _soilType,
        floodFrequency: _floodFreq,
        rainfallIntensity: _rainfall,
        elevationCategory: _elevation,
        distanceFromRiver: _distance);

    setState(() => _loading = true);
    try {
      final res = await ApiService.predict(input);
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => ResultsScreen(result: res)));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _loading = false);
    }
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
                value: _soilType,
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
                value: _elevation,
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
