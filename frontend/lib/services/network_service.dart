import 'package:connectivity_plus/connectivity_plus.dart';

class NetworkService {
  static final NetworkService _instance = NetworkService._internal();
  late Connectivity _connectivity;
  bool _isOnline = true;

  factory NetworkService() {
    return _instance;
  }

  NetworkService._internal() {
    _connectivity = Connectivity();
    _initConnectivity();
  }

  void _initConnectivity() {
    _connectivity.onConnectivityChanged.listen((result) {
      _isOnline = result != ConnectivityResult.none;
    });
  }

  Future<bool> checkConnectivity() async {
    final result = await _connectivity.checkConnectivity();
    _isOnline = result != ConnectivityResult.none;
    return _isOnline;
  }

  bool get isOnline => _isOnline;
  bool get isOffline => !_isOnline;

  String getStatus() {
    return _isOnline ? 'Online' : 'Offline - Using cached data';
  }
}
