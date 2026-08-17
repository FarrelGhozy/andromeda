import 'package:connectivity_plus/connectivity_plus.dart';

/// Wrapper tipis di atas connectivity_plus.
/// v6.x: `checkConnectivity`/`onConnectivityChanged` mengembalikan
/// `List<ConnectivityResult>` (bukan single result seperti v5).
class ConnectivityService {
  final Connectivity _connectivity = Connectivity();

  /// `true` jika ada jaringan (wifi/seluler/ethernet).
  /// CATATAN: jaringan ada ≠ internet ada — cross-check server tetap
  /// dilakukan di ConnectivityProvider.
  Future<bool> hasNetwork() async {
    final results = await _connectivity.checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }

  /// Stream perubahan status jaringan (perangkat).
  Stream<List<ConnectivityResult>> get onChanged =>
      _connectivity.onConnectivityChanged;
}
