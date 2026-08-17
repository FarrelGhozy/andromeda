import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/connectivity_service.dart';
import '../services/supabase_service.dart';

/// Sumber kebenaran status offline aplikasi (Fase 0 — offline mode).
///
/// Kombinasi dua sinyal:
/// 1. Koneksi perangkat (connectivity_plus) — jaringan ada/tidak.
/// 2. Server Supabase reachable (checkConnection) — internet benar-benar ada.
///
/// Aturan: offline = (tidak ada jaringan) ATAU (server tidak bisa dijangkau).
class ConnectivityProvider extends ChangeNotifier {
  final ConnectivityService _service = ConnectivityService();
  StreamSubscription<List<ConnectivityResult>>? _sub;

  bool _isOffline = false;
  bool get isOffline => _isOffline;

  /// Aktifkan listener perubahan koneksi. Panggil sekali dari main().
  void init() {
    _sub ??= _service.onChanged.listen((results) {
      final hasNet = results.any((r) => r != ConnectivityResult.none);
      if (hasNet) {
        // Ada jaringan → pastikan server Supabase benar-benar terjangkau
        // (connectivity_plus di emulator tidak stabil — jangan percaya buta).
        _checkServer();
      } else {
        _setOffline(true);
      }
    });
  }

  Future<void> _checkServer() async {
    bool reachable = false;
    try {
      reachable = await SupabaseService()
          .checkConnection()
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      reachable = false;
    }
    _setOffline(!reachable);
  }

  void _setOffline(bool offline) {
    if (_isOffline != offline) {
      _isOffline = offline;
      notifyListeners();
    }
  }

  /// Dipanggil splash screen setelah checkConnection manual, agar banner
  /// di homepage langsung akurat sebelum listener connectivity sempat jalan.
  void applyServerReachable(bool reachable) => _setOffline(!reachable);

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
