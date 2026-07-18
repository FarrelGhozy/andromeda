# 📱 Rancangan Aplikasi Flutter — ANDROMEDA

**Android Routine Monitoring Electronic Drip Automation**  
Sistem Irigasi Tetes Otomatis Berbasis IoT  
Program PDB (Program Desa Binaan) — **Desa Merayan**

> **Dokumen ini adalah panduan teknis untuk membangun aplikasi Flutter ANDROMEDA**  
> **Target:** Android (utama) + iOS (opsional)  
> **Versi Rancangan:** 1.0  
> **Tanggal:** 18 Juli 2026

---

## 📑 Daftar Isi

1. [Ringkasan](#ringkasan)
2. [Arsitektur Aplikasi](#arsitektur-aplikasi)
3. [Struktur Folder](#struktur-folder)
4. [Dependencies & pubspec.yaml](#dependencies--pubspecyaml)
5. [Model / Entity](#model--entity)
6. [Services / Repository](#services--repository)
7. [State Management](#state-management)
8. [Routing & Navigasi](#routing--navigasi)
9. [Theme & Desain](#theme--desain)
10. [Halaman & Widget](#halaman--widget)
11. [Integrasi Supabase](#integrasi-supabase)
12. [Pengujian](#pengujian)
13. [Build & Deploy](#build--deploy)
14. [Daftar Tugas Implementasi](#daftar-tugas-implementasi)

---

## Ringkasan

Aplikasi Flutter ANDROMEDA adalah antarmuka pengguna utama untuk memonitor dan mengontrol sistem irigasi tetes otomatis. Aplikasi ini berkomunikasi langsung dengan **Supabase** (backend) melalui REST API dan Realtime subscription.

### Tujuan Aplikasi

| Tujuan | Detail |
|--------|--------|
| Monitoring | Lihat kelembaban tanah real-time dari 6 petak |
| Kontrol | Buka/tutup solenoid valve manual |
| Otomatisasi | Atur threshold & mode auto/manual per petak |
| Histori | Grafik riwayat kelembaban harian/mingguan/bulanan |
| Konfigurasi | Atur interval, durasi valve, threshold |

### Target Pengguna

| Segmen | Level Teknis | Kebiasaan |
|--------|:------------:|-----------|
| Petani (utama) | Rendah | Gapakai HP Android, butuh UI besar & simpel |
| Penyuluh lapangan | Sedang | Butuh data historis & ekspor |
| Admin teknis | Tinggi | Butuh akses konfigurasi semua petak |

### Prinsip Desain Aplikasi

| Prinsip | Penerapan |
|---------|-----------|
| **Sederhana** | 3 tap maksimal untuk aksi utama |
| **Besar & Jelas** | Font besar, tombol besar (jari petani) |
| **Cepat** | Gunakan Realtime, cache lokal |
| **Offline-capable** | Mode luring dengan data terakhir tersimpan |
| **Hemat kuota** | Minim animasi, kompres gambar |

---

## Arsitektur Aplikasi

### Pola Arsitektur: MVVM + Repository

```
┌─────────────────────────────────────────────────────────────────────┐
│                        PRESENTATION LAYER                          │
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │  SCREENS (UI)                                                │   │
│  │  ┌──────────┐  ┌───────────────┐  ┌──────────┐  ┌────────┐  │   │
│  │  │ Splash   │  │ Home          │  │ Dashboard│  │Setting │  │   │
│  │  └──────────┘  └───────────────┘  └──────────┘  └────────┘  │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                              │                                      │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │  WIDGETS (Reusable UI)                                       │   │
│  │  DeviceCard, MoistureGauge, ValveButton, MoistureChart,      │   │
│  │  StatusBadge, ConfigSlider, LoadingOverlay, ErrorBanner      │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                              │                                      │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │  VIEWMODELS / PROVIDERS                                      │   │
│  │  ┌────────────┐  ┌───────────────────┐  ┌────────────────┐   │   │
│  │  │ Devices    │  │ DashboardProvider │  │ ConfigProvider │   │   │
│  │  │ Provider   │  │                   │  │                │   │   │
│  │  └────────────┘  └───────────────────┘  └────────────────┘   │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                              │                                      │
└──────────────────────────────┼──────────────────────────────────────┘
                               │
┌──────────────────────────────┼──────────────────────────────────────┐
│                    DOMAIN LAYER                                     │
│                               │                                     │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │  MODELS                                                     │   │
│  │  Device, SensorReading, SystemConfig, PendingCommand        │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
                               │
┌──────────────────────────────┼──────────────────────────────────────┐
│                       DATA LAYER                                    │
│                               │                                     │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │  REPOSITORIES                                               │   │
│  │  ┌────────────────┐  ┌───────────────────┐  ┌────────────┐  │   │
│  │  │ DeviceRepo     │  │ SensorRepo        │  │ ConfigRepo │  │   │
│  │  └────────────────┘  └───────────────────┘  └────────────┘  │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                              │                                      │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │  DATA SOURCES                                               │   │
│  │  ┌──────────────────────┐  ┌─────────────────────────────┐  │   │
│  │  │ SupabaseClient       │  │ LocalDatabase (Hive/SQLite)│  │   │
│  │  │ REST + Realtime      │  │ Cache data terakhir        │  │   │
│  │  └──────────────────────┘  └─────────────────────────────┘  │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### Aliran Data

```
USER TAP "BUKA VALVE"
     │
     ▼
DashboardScreen (UI)
     │
     ▼
DashboardProvider.toggleValve(deviceId, duration)
     │
     ▼
SensorRepository.sendCommand(deviceId, "VALVE_ON", duration)
     │
     ▼
SupabaseClient.from('pending_commands').insert({...})
     │
     ▼
SUPABASE CLOUD ← (ESP32 akan baca nanti)
     │
     ▼
DashboardProvider.updateStatus(deviceId, "command_sent")
     │
     ▼
UI rebuild — tampilkan "Perintah terkirim ✅"
```

### Aliran Data Realtime

```
ESP32 POST sensor_readings → Supabase
     │
     ▼
Supabase Realtime Publication
     │
     ▼
Supabase Flutter SDK — stream()
     │
     ▼
DashboardProvider — listen stream
     │
     ▼
UI rebuild otomatis — gauge & chart update
```

---

## Struktur Folder

```
mobile_app/
├── pubspec.yaml
├── analysis_options.yaml
├── android/
├── ios/
├── assets/
│   ├── images/
│   │   ├── logo.png                 ← Logo ANDROMEDA
│   │   ├── splash_bg.png            ← Background splash
│   │   └── empty_state.png          ← Ilustrasi data kosong
│   ├── fonts/                        ← Font lokal (opsional)
│   └── icons/                        ← Icon custom
│       ├── valve_open.png
│       ├── valve_closed.png
│       └── moisture_icon.png
├── test/
│   ├── models/
│   │   └── sensor_reading_test.dart
│   ├── services/
│   │   └── supabase_service_test.dart
│   ├── providers/
│   │   └── dashboard_provider_test.dart
│   └── widget_test.dart
└── lib/
    ├── main.dart                    ← Entry point
    ├── app.dart                     ← MaterialApp + routing
    │
    ├── config/
    │   ├── supabase_config.dart     ← Supabase URL + anon key
    │   └── theme_config.dart        ← Tema warna & font
    │
    ├── models/
    │   ├── device.dart              ← Model petak
    │   ├── sensor_reading.dart      ← Model data sensor
    │   ├── system_config.dart       ← Model konfigurasi
    │   └── pending_command.dart     ← Model perintah
    │
    ├── services/
    │   ├── supabase_service.dart    ← Init & wrapper Supabase
    │   ├── device_repository.dart   ← CRUD devices
    │   ├── sensor_repository.dart   ← CRUD sensor_readings
    │   └── config_repository.dart   ← CRUD system_config
    │
    ├── providers/
    │   ├── devices_provider.dart    ← State daftar petak
    │   ├── dashboard_provider.dart  ← State detail petak
    │   └── config_provider.dart     ← State konfigurasi
    │
    ├── screens/
    │   ├── splash_screen.dart       ← Splash + loading
    │   ├── home_screen.dart         ← Daftar 6 petak
    │   ├── dashboard_screen.dart    ← Detail 1 petak
    │   └── settings_screen.dart     ← Pengaturan global
    │
    └── widgets/
        ├── device_card.dart         ← Kartu petak di home
        ├── moisture_gauge.dart      ← Gauge melingkar
        ├── valve_button.dart        ← Tombol valve
        ├── moisture_chart.dart      ← Grafik fl_chart
        ├── status_badge.dart        ← Status online/offline
        ├── config_slider.dart       ← Slider threshold
        ├── duration_picker.dart     ← Picker durasi valve
        ├── loading_overlay.dart     ← Indikator loading
        └── error_banner.dart        ← Banner error
```

---

## Dependencies & pubspec.yaml

```yaml
name: andromeda_app
description: ANDROMEDA - Irigasi Tetes Otomatis Berbasis IoT
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: '>=3.2.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter

  # === Backend & Network ===
  supabase_flutter: ^2.8.0        # Supabase SDK (REST + Realtime)
  http: ^1.2.0                     # HTTP client fallback

  # === State Management ===
  provider: ^6.1.0                 # State management sederhana

  # === Chart ===
  fl_chart: ^0.69.0                # Grafik kelembaban

  # === UI Components ===
  google_fonts: ^6.2.0             # Font keren
  shimmer: ^3.0.0                  # Loading shimmer effect
  flutter_svg: ^2.0.0              # SVG icons
  cached_network_image: ^3.3.0     # Cache gambar

  # === Utility ===
  intl: ^0.19.0                    # Format tanggal
  connectivity_plus: ^6.0.0        # Deteksi koneksi internet
  package_info_plus: ^8.0.0        # Info versi app
  url_launcher: ^6.2.0             # Buka link eksternal
  share_plus: ^10.0.0              # Share data/CSV
  path_provider: ^2.1.0            # Path lokal untuk ekspor
  permission_handler: ^11.3.0      # Izin storage (ekspor CSV)

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0
  mockito: ^5.4.0                  # Mock untuk testing
  build_runner: ^2.4.0             # Code generation

flutter:
  uses-material-design: true

  assets:
    - assets/images/
    - assets/icons/
```

### Alasan Pemilihan Setiap Library

| Library | Mengapa? | Alternatif |
|---------|----------|------------|
| **supabase_flutter** | SDK resmi, realtime, offline | REST manual (ribet) |
| **provider** | Sederhana, bawaan Flutter, cukup | BLoC (overkill), Riverpod (baru) |
| **fl_chart** | Ringan, kustomisasi tinggi | Syncfusion (berat), charts_flutter (usang) |
| **shimmer** | UX mulus pas loading | Lottie (file besar) |
| **connectivity_plus** | Deteksi offline/online | Tanpa library (kurang akurat) |

---

## Model / Entity

### Device

```dart
// lib/models/device.dart
class Device {
  final int id;
  final String deviceId;     // "petak-01"
  final String name;         // "Petak 1 — Padi"
  final String location;     // "Lahan A"
  final String status;       // "active" | "inactive"
  final DateTime createdAt;

  Device({
    required this.id,
    required this.deviceId,
    required this.name,
    required this.location,
    this.status = 'active',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory Device.fromJson(Map<String, dynamic> json) => Device(
    id: json['id'],
    deviceId: json['device_id'],
    name: json['name'],
    location: json['location'] ?? '',
    status: json['status'] ?? 'active',
    createdAt: DateTime.parse(json['created_at']),
  );

  Map<String, dynamic> toJson() => {
    'device_id': deviceId,
    'name': name,
    'location': location,
    'status': status,
  };
}
```

### SensorReading

```dart
// lib/models/sensor_reading.dart
class SensorReading {
  final int id;
  final String deviceId;
  final int moisture;            // raw ADC (0-4095)
  final double moisturePercent;  // 0-100%
  final String valveStatus;      // "ON" | "OFF"
  final double? batteryVoltage;  // tegangan aki (opsional)
  final int? rssi;               // kekuatan WiFi (opsional)
  final DateTime createdAt;

  SensorReading({...});

  // Helper: apakah tanah kering?
  bool isDry(int thresholdDry) => moisturePercent < thresholdDry;
  
  // Helper: apakah tanah basah?
  bool isWet(int thresholdWet) => moisturePercent > thresholdWet;

  factory SensorReading.fromJson(Map<String, dynamic> json) => ...;
  Map<String, dynamic> toJson() => ...;
}
```

### SystemConfig

```dart
// lib/models/system_config.dart
class SystemConfig {
  final int id;
  final String deviceId;
  String mode;              // "auto" | "manual"
  int thresholdDry;         // % (default 30)
  int thresholdWet;         // % (default 70)
  int valveDuration;        // detik (default 30)
  int readInterval;         // detik (default 1800)
  DateTime updatedAt;

  SystemConfig({...});

  bool get isAutoMode => mode == 'auto';
  bool get isManualMode => mode == 'manual';

  // Validasi threshold
  bool get isValid => thresholdDry < thresholdWet;

  factory SystemConfig.fromJson(Map<String, dynamic> json) => ...;
  Map<String, dynamic> toJson() => ...;
}
```

### PendingCommand

```dart
// lib/models/pending_command.dart
class PendingCommand {
  final int? id;
  final String deviceId;
  final String command;      // "VALVE_ON" | "VALVE_OFF"
  final int duration;        // detik (untuk VALVE_ON)
  final String status;       // "pending" | "executed" | "cancelled"
  final DateTime createdAt;

  PendingCommand({...});

  // Helper
  bool get isPending => status == 'pending';
  bool get isOpenCommand => command == 'VALVE_ON';

  factory PendingCommand.fromJson(Map<String, dynamic> json) => ...;
  Map<String, dynamic> toJson() => ...;
}
```

### Enum & Helper Types

```dart
// lib/models/enums.dart
enum ValveStatus { on, off, unknown }
enum DeviceMode { auto, manual }
enum DeviceStatus { active, inactive, maintenance }
enum ConnectionStatus { connected, disconnected, error }

// Extension untuk konversi
extension ValveStatusX on ValveStatus {
  String get label => name.toUpperCase();
  bool get isOpen => this == ValveStatus.on;
  Color get color => switch (this) {
    ValveStatus.on => Colors.red,
    ValveStatus.off => Colors.green,
    ValveStatus.unknown => Colors.grey,
  };
}
```

---

## Services / Repository

### SupabaseService — Inisialisasi

```dart
// lib/services/supabase_service.dart
class SupabaseService {
  static final SupabaseService _instance = SupabaseService._();
  factory SupabaseService() => _instance;
  SupabaseService._();

  SupabaseClient get client => Supabase.instance.client;

  Future<void> init() async {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
      realtimeClientOptions: RealtimeClientOptions(
        // Keep-alive setiap 10 detik
        heartbeatInterval: const Duration(seconds: 10),
      ),
    );
    debugPrint('✅ Supabase initialized');
  }

  // Cek koneksi
  Future<bool> checkConnection() async {
    try {
      await client.from('devices').select('count', count: Exact).limit(1);
      return true;
    } catch (e) {
      return false;
    }
  }
}
```

### DeviceRepository

```dart
// lib/services/device_repository.dart
class DeviceRepository {
  final SupabaseClient _client;

  DeviceRepository(this._client);

  // === READ ===
  /// Ambil semua device (realtime stream)
  Stream<List<Device>> getDevicesStream() {
    return _client
        .from('devices')
        .stream(primaryKey: ['id'])
        .order('id');
  }

  /// Ambil device by ID
  Future<Device?> getDevice(String deviceId) async {
    final response = await _client
        .from('devices')
        .select()
        .eq('device_id', deviceId)
        .single()
        .execute();
    return response.data != null 
        ? Device.fromJson(response.data as Map<String, dynamic>)
        : null;
  }

  /// Ambil data sensor terbaru (untuk home screen)
  Future<Map<String, SensorReading?>> getLatestReadings() async {
    // Ambil data terbaru dari tiap petak via RPC atau query manual
    // Bisa pakai fungsi Supabase `get_latest_readings()`
    final response = await _client.rpc('get_latest_readings');
    final list = response.data as List;
    return {
      for (var item in list)
        item['device_id'] as String: SensorReading.fromJson(item),
    };
  }
}
```

### SensorRepository

```dart
// lib/services/sensor_repository.dart
class SensorRepository {
  final SupabaseClient _client;

  SensorRepository(this._client);

  /// Stream realtime data sensor untuk 1 petak
  Stream<List<SensorReading>> getSensorStream(String deviceId, {int limit = 100}) {
    return _client
        .from('sensor_readings')
        .stream(primaryKey: ['id'])
        .eq('device_id', deviceId)
        .order('created_at', ascending: false)
        .limit(limit);
  }

  /// Ambil data historis untuk chart
  Future<List<SensorReading>> getHistory({
    required String deviceId,
    required DateTime since,
    required DateTime until,
  }) async {
    final response = await _client
        .from('sensor_readings')
        .select()
        .eq('device_id', deviceId)
        .gte('created_at', since.toIso8601String())
        .lte('created_at', until.toIso8601String())
        .order('created_at', ascending: true);
    
    return (response.data as List)
        .map((e) => SensorReading.fromJson(e))
        .toList();
  }

  /// Kirim perintah ke valve
  Future<void> sendCommand({
    required String deviceId,
    required String command,
    int duration = 30,
  }) async {
    await _client.from('pending_commands').insert({
      'device_id': deviceId,
      'command': command,
      'duration': duration,
      'status': 'pending',
      'source': 'android',
    });
  }
}
```

### ConfigRepository

```dart
// lib/services/config_repository.dart
class ConfigRepository {
  final SupabaseClient _client;

  ConfigRepository(this._client);

  /// Stream konfigurasi realtime
  Stream<SystemConfig?> getConfigStream(String deviceId) {
    return _client
        .from('system_config')
        .stream(primaryKey: ['id'])
        .eq('device_id', deviceId)
        .limit(1)
        .map((list) => list.isNotEmpty
            ? SystemConfig.fromJson(list.first as Map<String, dynamic>)
            : null);
  }

  /// Update konfigurasi
  Future<void> updateConfig(String deviceId, SystemConfig config) async {
    await _client
        .from('system_config')
        .update({
          'mode': config.mode,
          'threshold_dry': config.thresholdDry,
          'threshold_wet': config.thresholdWet,
          'valve_duration': config.valveDuration,
          'read_interval': config.readInterval,
          'updated_by': 'android',
        })
        .eq('device_id', deviceId);
  }

  /// Ambil konfigurasi sekali (tidak stream)
  Future<SystemConfig?> getConfig(String deviceId) async {
    final response = await _client
        .from('system_config')
        .select()
        .eq('device_id', deviceId)
        .single()
        .execute();
    return response.data != null
        ? SystemConfig.fromJson(response.data as Map<String, dynamic>)
        : null;
  }
}
```

---

## State Management

### Provider Architecture

```
MultiProvider (di main.dart)
  │
  ├── DevicesProvider       ← Daftar semua petak
  │     └─ Stream<List<Device>>
  │
  ├── DashboardProvider     ← Data detail 1 petak
  │     ├─ SensorReading? latestReading
  │     ├─ List<SensorReading> history
  │     ├─ SystemConfig? config
  │     ├─ bool isLoading
  │     ├─ ValveStatus valveStatus
  │     └─ String? errorMessage
  │
  └── ConfigProvider        ← Konfigurasi global (settings)
        ├─ bool notificationEnabled
        └─ String selectedTheme
```

### DevicesProvider

```dart
// lib/providers/devices_provider.dart
class DevicesProvider extends ChangeNotifier {
  final DeviceRepository _deviceRepo;
  final SensorRepository _sensorRepo;

  List<Device> _devices = [];
  Map<String, SensorReading?> _latestReadings = {};
  bool _isLoading = true;
  String? _error;

  // Getters
  List<Device> get devices => _devices;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Dapatkan reading terbaru untuk device tertentu
  SensorReading? latestFor(String deviceId) => _latestReadings[deviceId];

  DevicesProvider(this._deviceRepo, this._sensorRepo);

  /// Init: subscribe ke stream devices
  void init() {
    _deviceRepo.getDevicesStream().listen((devices) {
      _devices = devices;
      _isLoading = false;
      notifyListeners();
    });
  }

  /// Refresh data terbaru semua petak
  Future<void> refreshReadings() async {
    try {
      _latestReadings = await _deviceRepo.getLatestReadings();
      notifyListeners();
    } catch (e) {
      _error = 'Gagal memuat data: $e';
      notifyListeners();
    }
  }
}
```

### DashboardProvider

```dart
// lib/providers/dashboard_provider.dart
enum DashboardState { loading, ready, error }

class DashboardProvider extends ChangeNotifier {
  final SensorRepository _sensorRepo;
  final ConfigRepository _configRepo;

  String _deviceId = '';
  DashboardState _state = DashboardState.loading;
  
  SensorReading? _latestReading;
  List<SensorReading> _history = [];
  SystemConfig? _config;
  String? _errorMessage;
  int _selectedChartDays = 1;

  // Getters
  String get deviceId => _deviceId;
  DashboardState get state => _state;
  SensorReading? get latestReading => _latestReading;
  List<SensorReading> get history => _history;
  SystemConfig? get config => _config;
  String? get errorMessage => _errorMessage;
  int get selectedChartDays => _selectedChartDays;

  bool get isValveOpen => _latestReading?.valveStatus == 'ON';

  DashboardProvider(this._sensorRepo, this._configRepo);

  /// Load data untuk petak
  Future<void> loadDevice(String deviceId) async {
    _deviceId = deviceId;
    _state = DashboardState.loading;
    notifyListeners();

    try {
      // Subscribe realtime sensor readings
      _sensorRepo.getSensorStream(deviceId, limit: 1).listen((list) {
        if (list.isNotEmpty) {
          _latestReading = list.first;
          notifyListeners();
        }
      });

      // Subscribe realtime config
      _configRepo.getConfigStream(deviceId).listen((config) {
        _config = config;
        notifyListeners();
      });

      // Load history
      await _loadHistory();

      _state = DashboardState.ready;
    } catch (e) {
      _state = DashboardState.error;
      _errorMessage = e.toString();
    }
    notifyListeners();
  }

  /// Load history chart
  Future<void> _loadHistory() async {
    final since = DateTime.now().subtract(Duration(days: _selectedChartDays));
    _history = await _sensorRepo.getHistory(
      deviceId: _deviceId,
      since: since,
      until: DateTime.now(),
    );
  }

  /// Ganti rentang chart
  Future<void> setChartDays(int days) async {
    _selectedChartDays = days;
    await _loadHistory();
    notifyListeners();
  }

  /// Kirim perintah valve
  Future<void> sendValveCommand(String command, {int duration = 30}) async {
    try {
      await _sensorRepo.sendCommand(
        deviceId: _deviceId,
        command: command,
        duration: duration,
      );
    } catch (e) {
      _errorMessage = 'Gagal kirim perintah: $e';
      notifyListeners();
    }
  }

  /// Update config
  Future<void> updateConfig(SystemConfig newConfig) async {
    try {
      await _configRepo.updateConfig(_deviceId, newConfig);
    } catch (e) {
      _errorMessage = 'Gagal update config: $e';
      notifyListeners();
    }
  }
}
```

### Aliran State & Rebuild

```
Data dari Supabase
      │
      ▼
Supabase.stream()     ← Realtime via WebSocket
      │
      ▼
Provider.listen()     ← Otomatis karena stream
      │
      ▼
notifyListeners()     ← Beritahu UI
      │
      ▼
Consumer<T>(builder)  ← Hanya rebuild widget yg perlu
      │
      ▼
UI Update             ← Gauge, chart, status berubah
```

---

## Routing & Navigasi

### Route Definitions

```dart
// lib/app.dart
class AppRoutes {
  static const String splash = '/';
  static const String home = '/home';
  static const String dashboard = '/dashboard';  // + args: deviceId
  static const String settings = '/settings';
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ANDROMEDA',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.light,

      initialRoute: AppRoutes.splash,

      onGenerateRoute: (settings) {
        switch (settings.name) {
          case AppRoutes.splash:
            return MaterialPageRoute(builder: (_) => const SplashScreen());

          case AppRoutes.home:
            return MaterialPageRoute(builder: (_) => const HomeScreen());

          case AppRoutes.dashboard:
            final deviceId = settings.arguments as String;
            return MaterialPageRoute(
              builder: (_) => DashboardScreen(deviceId: deviceId),
            );

          case AppRoutes.settings:
            return MaterialPageRoute(builder: (_) => const SettingsScreen());

          default:
            return MaterialPageRoute(builder: (_) => const SplashScreen());
        }
      },
    );
  }
}
```

### Navigasi Antar Halaman

```
SplashScreen
  │  (2 detik, init Supabase, cek koneksi)
  │
  ▼
HomeScreen
  │  (Daftar 6 petak, tap salah satu)
  │
  ├──► DashboardScreen(deviceId: "petak-01")
  │     │  (Detail 1 petak: gauge, valve, chart, config)
  │     │
  │     └── (Tombol kembali) ──► HomeScreen
  │
  └──► SettingsScreen
        │  (Pengaturan global: notifikasi, tentang)
        │
        └── (Tombol kembali) ──► HomeScreen
```

### Diagram Navigasi

```
┌──────────────┐     ┌──────────────┐     ┌──────────────────┐
│  Splash      │────►│  Home        │────►│  Dashboard       │
│  Screen      │     │  Screen      │     │  Screen          │
│              │     │              │     │  (detail petak)  │
│  Init        │     │  List petak  │     │                  │
│  Cek konek   │     │  Ringkasan   │◄────│  Back ←          │
└──────────────┘     └──────┬───────┘     └──────────────────┘
                            │
                            │
                    ┌───────▼───────┐
                    │  Settings     │
                    │  Screen       │
                    │               │
                    │  Notifikasi   │
                    │  Tentang      │
                    │  Ekspor       │
                    └───────────────┘
```

---

## Theme & Desain

### Palet Warna

```dart
// lib/config/theme_config.dart
class AppTheme {
  // === Warna Utama ===
  static const Color primaryGreen = Color(0xFF2E7D32);    // Hijau alam
  static const Color primaryDark = Color(0xFF1B5E20);     // Hijau gelap
  static const Color primaryLight = Color(0xFFA5D6A7);    // Hijau muda

  static const Color accentBlue = Color(0xFF1565C0);      // Biru air
  static const Color accentOrange = Color(0xFFE65100);    // Oranye matahari
  
  // === Warna Status ===
  static const Color success = Color(0xFF4CAF50);          // Valve OFF (aman)
  static const Color danger = Color(0xFFF44336);           // Valve ON / error
  static const Color warning = Color(0xFFFFC107);          // Kelembaban kritis
  static const Color offline = Color(0xFF9E9E9E);          // Device offline

  // === Background ===
  static const Color bgLight = Color(0xFFF5F5F5);
  static const Color cardBg = Colors.white;
  static const Color bgDark = Color(0xFF121212);
  static const Color cardBgDark = Color(0xFF1E1E1E);

  // === Font ===
  static const String fontFamily = 'PlusJakartaSans';

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primarySwatch: Colors.green,
    colorScheme: ColorScheme.light(
      primary: primaryGreen,
      secondary: accentBlue,
      tertiary: accentOrange,
      surface: bgLight,
      error: danger,
    ),
    fontFamily: fontFamily,
    appBarTheme: const AppBarTheme(
      backgroundColor: primaryGreen,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
    ),
    cardTheme: CardTheme(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: primaryGreen,
      foregroundColor: Colors.white,
    ),
  );

  // Sama untuk dark theme (dengan warna gelap)
  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primarySwatch: Colors.green,
    colorScheme: ColorScheme.dark(
      primary: primaryLight,
      secondary: accentBlue,
      surface: bgDark,
      error: danger,
    ),
    fontFamily: fontFamily,
    cardTheme: CardTheme(
      elevation: 2,
      color: cardBgDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    // ...
  );
}
```

### Ukuran Font (Ramah Petani)

| Elemen | Ukuran | Weight |
|--------|:------:|--------|
| Judul halaman | 20sp | Bold |
| Nama petak | 18sp | SemiBold |
| Nilai kelembaban (gauge) | 48sp | Bold |
| Label | 14sp | Medium |
| Tombol valve | 16sp | SemiBold |
| Data kecil (timestamp) | 12sp | Regular |
| Tombol navigasi bawah | 12sp | Medium |

### Spacing System

```dart
class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}
```

---

## Halaman & Widget

### 1. SplashScreen

```dart
// lib/screens/splash_screen.dart
class SplashScreen extends StatefulWidget {
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    try {
      // 1. Init Supabase
      await SupabaseService().init();

      // 2. Cek koneksi
      final connected = await SupabaseService().checkConnection();

      if (!mounted) return;

      if (connected) {
        // 3. Navigasi ke Home
        Navigator.pushReplacementNamed(context, AppRoutes.home);
      } else {
        _showError('Tidak terhubung ke server.\nPeriksa koneksi internet.');
      }
    } catch (e) {
      _showError('Gagal inisialisasi: $e');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo
            Image.asset('assets/images/logo.png', height: 120),
            SizedBox(height: 24),
            Text('ANDROMEDA', style: Theme.of(context).textTheme.headlineLarge),
            Text('Irigasi Tetes Otomatis', style: Theme.of(context).textTheme.bodyLarge),
            SizedBox(height: 48),
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Menghubungkan...'),
            SizedBox(height: 48),
            Text('Teknologi Tepat Guna untuk Petani Indonesia',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
```

#### Mockup SplashScreen

```
┌──────────────────────────────────┐
│                                  │
│                                  │
│                                  │
│            🚀 ANDROMEDA          │
│        Irigasi Tetes Otomatis    │
│           Berbasis IoT           │
│                                  │
│           ◌ (loading)            │
│         Menghubungkan...         │
│                                  │
│                                  │
│    Teknologi Tepat Guna untuk    │
│        Petani Indonesia          │
│                                  │
│         v1.0.0                   │
└──────────────────────────────────┘
```

### 2. HomeScreen

```dart
// lib/screens/home_screen.dart
class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ANDROMEDA'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.pushNamed(context, AppRoutes.settings),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<DevicesProvider>().refreshReadings(),
          ),
        ],
      ),
      body: Consumer<DevicesProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.error != null) {
            return ErrorBanner(message: provider.error!);
          }

          return RefreshIndicator(
            onRefresh: provider.refreshReadings,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: provider.devices.length,
              itemBuilder: (context, index) {
                final device = provider.devices[index];
                final reading = provider.latestFor(device.deviceId);
                return DeviceCard(
                  device: device,
                  reading: reading,
                  onTap: () => Navigator.pushNamed(
                    context, AppRoutes.dashboard,
                    arguments: device.deviceId,
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
```

#### Mockup HomeScreen

```
┌──────────────────────────────────┐
│ 🌾 ANDROMEDA          ⚙️ 🔄    │
├──────────────────────────────────┤
│                                  │
│ ┌──────────────────────────────┐ │
│ │ 🌱 Petak 1 — Padi           │ │
│ │ Lahan A            🟢 Online │ │
│ │                              │ │
│ │    ╔══════════════╗          │ │
│ │    ║    42%       ║          │ │
│ │    ║  Lembab      ║          │ │
│ │    ╚══════════════╝          │ │
│ │                              │ │
│ │ Valve: OFF     ⏰ 2 menit    │ │
│ │                              │ │
│ │ [🔓 BUKA]     [⚙️ Atur]    │ │
│ └──────────────────────────────┘ │
│                                  │
│ ┌──────────────────────────────┐ │
│ │ 🌱 Petak 2 — Padi           │ │
│ │ Lahan A            🟢 Online │ │
│ │                              │ │
│ │    ╔══════════════╗          │ │
│ │    ║    68%       ║          │ │
│ │    ║  Lembab      ║          │ │
│ │    ╚══════════════╝          │ │
│ │                              │ │
│ │ Valve: OFF     ⏰ 5 menit    │ │
│ │                              │ │
│ │ [🔓 BUKA]     [⚙️ Atur]    │ │
│ └──────────────────────────────┘ │
│                                  │
│ ┌──────────────────────────────┐ │
│ │ 🌶️ Petak 3 — Cabai          │ │
│ │ Lahan A            🟢 Online │ │
│ │                              │ │
│ │    ╔══════════════╗          │ │
│ │    ║    22% 🔴    ║          │ │
│ │    ║   KERING!    ║          │ │
│ │    ╚══════════════╝          │ │
│ │                              │ │
│ │ Valve: OFF    ⏰ 1 menit 🔥 │ │
│ │                              │ │
│ │ [🔓 BUKA]     [⚙️ Atur]    │ │
│ └──────────────────────────────┘ │
│                                  │
│ ... 3 petak lainnya...           │
│                                  │
└──────────────────────────────────┘
│
└── BottomNav: [🏠 Beranda] [📊 Grafik] [⚙️ Setting]
```

### 3. DeviceCard Widget

```dart
// lib/widgets/device_card.dart
class DeviceCard extends StatelessWidget {
  final Device device;
  final SensorReading? reading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final moisture = reading?.moisturePercent ?? 0;
    final valveStatus = reading?.valveStatus ?? 'OFF';
    final timeAgo = reading?.createdAt != null
        ? _formatTimeAgo(reading!.createdAt)
        : 'Belum ada data';

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Gauge kecil (kiri)
              SizedBox(
                width: 80, height: 80,
                child: MoistureGauge(
                  percent: moisture,
                  size: 80,
                  showLabel: false,
                ),
              ),
              SizedBox(width: 16),

              // Info tengah
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          device.name.contains('Cabai')
                              ? Icons.whatshot
                              : Icons.eco,
                          color: Colors.green,
                        ),
                        SizedBox(width: 8),
                        Text(
                          device.name,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      '${device.location}  •  Kelembaban: ${moisture.toStringAsFixed(0)}%',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        StatusBadge(
                          text: valveStatus == 'ON' ? 'Valve ON' : 'Valve OFF',
                          color: valveStatus == 'ON'
                              ? AppTheme.danger : AppTheme.success,
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.access_time, size: 14, color: Colors.grey),
                        SizedBox(width: 4),
                        Text(timeAgo, style: TextStyle(
                          fontSize: 12, color: Colors.grey[500],
                        )),
                      ],
                    ),
                  ],
                ),
              ),

              // Chevron kanan
              Icon(Icons.chevron_right, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m lalu';
    return '${diff.inHours}h lalu';
  }
}
```

### 4. MoistureGauge (Gauge Lingkaran)

```dart
// lib/widgets/moisture_gauge.dart
class MoistureGauge extends StatelessWidget {
  final double percent;       // 0-100
  final double size;          // Px
  final bool showLabel;       // Tampilkan % di tengah?

  @override
  Widget build(BuildContext context) {
    // Warna berdasarkan level
    Color color;
    String label;
    if (percent < 30) {
      color = AppTheme.danger;     // Merah (kering)
      label = 'KERING';
    } else if (percent < 70) {
      color = AppTheme.warning;    // Kuning (lembab)
      label = 'LEMBAB';
    } else {
      color = AppTheme.primaryGreen; // Hijau (basah)
      label = 'BASAH';
    }

    return CustomPaint(
      size: Size(size, size),
      painter: _GaugePainter(
        percent: percent / 100,
        color: color,
        backgroundColor: Colors.grey[200]!,
        strokeWidth: 10,
      ),
      child: showLabel
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${percent.toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            )
          : null,
    );
  }
}

// Custom Painter untuk arc gauge
class _GaugePainter extends CustomPainter {
  final double percent;
  final Color color;
  final Color backgroundColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Background arc (full circle)
    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    // Foreground arc (persentase)
    final fgPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    
    final sweepAngle = 2 * 3.14159 * percent;
    canvas.drawArc(rect, -3.14159 / 2, sweepAngle, false, fgPaint);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) => old.percent != percent;
}
```

### 5. DashboardScreen

```dart
// lib/screens/dashboard_screen.dart
class DashboardScreen extends StatefulWidget {
  final String deviceId;
  const DashboardScreen({required this.deviceId});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Load data setelah build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DashboardProvider>().loadDevice(widget.deviceId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.deviceId.toUpperCase()),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () => context.read<DashboardProvider>().loadDevice(widget.deviceId),
          ),
        ],
      ),
      body: Consumer<DashboardProvider>(
        builder: (context, provider, _) {
          switch (provider.state) {
            case DashboardState.loading:
              return const Center(child: CircularProgressIndicator());
            case DashboardState.error:
              return ErrorBanner(message: provider.errorMessage ?? 'Error');
            case DashboardState.ready:
              return _buildDashboard(context, provider);
          }
        },
      ),
    );
  }

  Widget _buildDashboard(BuildContext context, DashboardProvider provider) {
    return RefreshIndicator(
      onRefresh: () => provider.loadDevice(widget.deviceId),
      child: SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // === Bagian 1: Gauge Kelembaban ===
            _buildGaugeSection(provider),

            SizedBox(height: 16),

            // === Bagian 2: Status Valve ===
            _buildValveSection(provider),

            SizedBox(height: 16),

            // === Bagian 3: Kontrol Valve ===
            _buildValveControl(provider),

            SizedBox(height: 16),

            // === Bagian 4: Grafik Historis ===
            _buildChartSection(provider),

            SizedBox(height: 16),

            // === Bagian 5: Konfigurasi ===
            _buildConfigSection(provider),
          ],
        ),
      ),
    );
  }

  Widget _buildGaugeSection(DashboardProvider provider) {
    final reading = provider.latestReading;
    return Card(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          children: [
            Text(
              'Kelembaban Tanah',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SizedBox(height: 16),
            MoistureGauge(
              percent: reading?.moisturePercent ?? 0,
              size: 200,
              showLabel: true,
            ),
            SizedBox(height: 8),
            Text(
              'ADC Raw: ${reading?.moisture ?? 0}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildValveSection(DashboardProvider provider) {
    final isOpen = provider.isValveOpen;
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Status Valve', style: TextStyle(fontWeight: FontWeight.w600)),
                SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      isOpen ? Icons.water_drop : Icons.water_drop_outlined,
                      color: isOpen ? AppTheme.danger : AppTheme.success,
                      size: 28,
                    ),
                    SizedBox(width: 8),
                    Text(
                      isOpen ? 'TERBUKA 🚿' : 'TERTUTUP ✅',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isOpen ? AppTheme.danger : AppTheme.success,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            StatusBadge(
              text: provider.config?.isAutoMode == true ? 'Otomatis' : 'Manual',
              color: provider.config?.isAutoMode == true
                  ? AppTheme.primaryGreen : AppTheme.accentOrange,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildValveControl(DashboardProvider provider) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Text('Kontrol Valve', style: TextStyle(fontWeight: FontWeight.w600)),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => provider.sendValveCommand('VALVE_ON', duration: 30),
                    icon: Icon(Icons.play_arrow, color: Colors.white),
                    label: Text('BUKA VALVE'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.danger,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => provider.sendValveCommand('VALVE_OFF'),
                    icon: Icon(Icons.stop, color: Colors.white),
                    label: Text('TUTUP'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.success,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            DurationPicker(
              onSelected: (duration) {
                provider.sendValveCommand('VALVE_ON', duration: duration);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartSection(DashboardProvider provider) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Riwayat Kelembaban',
                  style: TextStyle(fontWeight: FontWeight.w600)),
                Row(
                  children: [
                    ChoiceChip(label: Text('1H'), selected: provider.selectedChartDays == 1, onSelected: (_) => provider.setChartDays(1)),
                    SizedBox(width: 4),
                    ChoiceChip(label: Text('7H'), selected: provider.selectedChartDays == 7, onSelected: (_) => provider.setChartDays(7)),
                    SizedBox(width: 4),
                    ChoiceChip(label: Text('30H'), selected: provider.selectedChartDays == 30, onSelected: (_) => provider.setChartDays(30)),
                  ],
                ),
              ],
            ),
            SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: MoistureChart(
                data: provider.history,
                thresholdDry: provider.config?.thresholdDry ?? 30,
                thresholdWet: provider.config?.thresholdWet ?? 70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigSection(DashboardProvider provider) {
    final config = provider.config;
    if (config == null) return SizedBox.shrink();

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Konfigurasi', style: TextStyle(fontWeight: FontWeight.w600)),
            SizedBox(height: 16),

            // Mode
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Mode'),
                ToggleButtons(
                  isSelected: [config.isAutoMode, config.isManualMode],
                  onPressed: (index) {
                    config.mode = index == 0 ? 'auto' : 'manual';
                    provider.updateConfig(config);
                  },
                  children: [Text('Otomatis'), Text('Manual')],
                ),
              ],
            ),
            Divider(),

            // Threshold kering
            ConfigSlider(
              label: 'Threshold Kering',
              value: config.thresholdDry.toDouble(),
              min: 10, max: 60,
              onChanged: (v) {
                config.thresholdDry = v.round();
                provider.updateConfig(config);
              },
            ),
            Divider(),

            // Threshold basah
            ConfigSlider(
              label: 'Threshold Basah',
              value: config.thresholdWet.toDouble(),
              min: 40, max: 90,
              onChanged: (v) {
                config.thresholdWet = v.round();
                provider.updateConfig(config);
              },
            ),
            Divider(),

            // Durasi valve
            ConfigSlider(
              label: 'Durasi Valve (detik)',
              value: config.valveDuration.toDouble(),
              min: 5, max: 120,
              divisions: 23,
              onChanged: (v) {
                config.valveDuration = v.round();
                provider.updateConfig(config);
              },
            ),
            Divider(),

            // Interval baca
            ConfigSlider(
              label: 'Interval Baca (menit)',
              value: (config.readInterval / 60).toDouble(),
              min: 5, max: 120,
              divisions: 23,
              onChanged: (v) {
                config.readInterval = (v * 60).round();
                provider.updateConfig(config);
              },
            ),
          ],
        ),
      ),
    );
  }
}
```

#### Mockup DashboardScreen (Bagian Atas)

```
┌──────────────────────────────────┐
│ ← PETAK-1 — PADI       🔄      │
├──────────────────────────────────┤
│                                  │
│ ┌──────────────────────────────┐ │
│ │     Kelembaban Tanah         │ │
│ │                              │ │
│ │         ╔══════════╗         │ │
│ │         ║   42%    ║         │ │
│ │         ║ LEMBAB   ║         │ │
│ │         ╚══════════╝         │ │
│ │                              │ │
│ │         ADC: 2200            │ │
│ └──────────────────────────────┘ │
│                                  │
│ ┌──────────────────────────────┐ │
│ │ Status Valve          [Otomatis] │
│ │                              │ │
│ │ 💧 TERTUTUP ✅              │ │
│ └──────────────────────────────┘ │
│                                  │
│ ┌──────────────────────────────┐ │
│ │     Kontrol Valve            │ │
│ │                              │ │
│ │ [▶ BUKA VALVE] [■ TUTUP]    │ │
│ │                              │ │
│ │ [15s] [30s] [60s] [120s]    │ │
│ └──────────────────────────────┘ │
│                                  │
│ ┌──────────────────────────────┐ │
│ │ Riwayat Kelembaban          │ │
│ │                      [1H][7H][30H]│
│ │                              │ │
│ │ 80%┤    ╱╲    ╱╲    ╱╲      │ │
│ │ 60%┤ ╱╱  ╲╲╱╱  ╲╲╱╱  ╲╲   │ │
│ │ 40%┤╱╱    ╲╲╱╱    ╲╲╱╱    │ │
│ │ 20%┤                        │ │
│ │    └─────────────────────   │ │
│ │      06  09  12  15  18     │ │
│ │ ── Kering (30%)            │ │
│ │ ── Basah (70%)             │ │
│ └──────────────────────────────┘ │
│                                  │
│ ┌──────────────────────────────┐ │
│ │     Konfigurasi              │ │
│ │                              │ │
│ │ Mode: [Otomatis] [Manual]   │ │
│ │                              │ │
│ │ Threshold Kering:    30% ═══│ │
│ │                              │ │
│ │ Threshold Basah:     70% ═══│ │
│ │                              │ │
│ │ Durasi Valve:      30 dtk ══│ │
│ │                              │ │
│ │ Interval:          30 mnt ══│ │
│ └──────────────────────────────┘ │
└──────────────────────────────────┘
```

### 6. MoistureChart Widget

```dart
// lib/widgets/moisture_chart.dart
class MoistureChart extends StatelessWidget {
  final List<SensorReading> data;
  final int thresholdDry;
  final int thresholdWet;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return Center(child: Text('Belum ada data'));
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 20,
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) => Text('${value.toInt()}%'),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: (data.length / 5).ceilToDouble(),
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx >= data.length) return SizedBox.shrink();
                return Text(
                  DateFormat('HH:mm').format(data[idx].createdAt),
                  style: TextStyle(fontSize: 10),
                );
              },
            ),
          ),
        ),

        // === Threshold lines ===
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            HorizontalLine(
              y: thresholdDry.toDouble(),
              color: Colors.red.withOpacity(0.3),
              strokeWidth: 1,
              dashArray: [5, 5],
              label: HorizontalLineLabel(
                show: true,
                labelResolver: (line) => 'Kering ${thresholdDry}%',
              ),
            ),
            HorizontalLine(
              y: thresholdWet.toDouble(),
              color: Colors.blue.withOpacity(0.3),
              strokeWidth: 1,
              dashArray: [5, 5],
              label: HorizontalLineLabel(
                show: true,
                labelResolver: (line) => 'Basah ${thresholdWet}%',
              ),
            ),
          ],
        ),

        // === Line data ===
        lineBarsData: [
          LineChartBarData(
            spots: data.asMap().entries.map((e) =>
              FlSpot(e.key.toDouble(), e.value.moisturePercent),
            ).toList(),
            isCurved: true,
            color: AppTheme.primaryGreen,
            barWidth: 2,
            dotData: FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: AppTheme.primaryGreen.withOpacity(0.1),
            ),
          ),
        ],

        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (spots) => spots.map((s) =>
              LineTooltipItem(
                '${s.y.toStringAsFixed(0)}%',
                TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ).toList(),
          ),
        ),
      ),
    );
  }
}
```

### 7. ErrorBanner Widget

```dart
// lib/widgets/error_banner.dart
class ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off, size: 64, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text(
              'Gagal Memuat Data',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            if (onRetry != null) ...[
              SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: Icon(Icons.refresh),
                label: Text('Coba Lagi'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
```

### 8. SettingsScreen

```dart
// lib/screens/settings_screen.dart
class SettingsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Pengaturan')),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          // === Koneksi ===
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Status Koneksi', style: TextStyle(fontWeight: FontWeight.w600)),
                  SizedBox(height: 12),
                  FutureBuilder<bool>(
                    future: SupabaseService().checkConnection(),
                    builder: (context, snapshot) {
                      final connected = snapshot.data ?? false;
                      return Row(
                        children: [
                          Icon(
                            connected ? Icons.check_circle : Icons.error,
                            color: connected ? AppTheme.success : AppTheme.danger,
                          ),
                          SizedBox(width: 8),
                          Text(connected ? 'Terhubung' : 'Terputus'),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // === Notifikasi ===
          Card(
            child: SwitchListTile(
              title: Text('Notifikasi'),
              subtitle: Text('Alert saat kelembaban kritis'),
              value: true,
              onChanged: (v) {},
            ),
          ),

          // === Ekspor Data ===
          Card(
            child: ListTile(
              leading: Icon(Icons.download),
              title: Text('Ekspor Data CSV'),
              subtitle: Text('Download riwayat sensor'),
              trailing: Icon(Icons.chevron_right),
              onTap: () => _exportData(context),
            ),
          ),

          // === Tentang ===
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('Tentang ANDROMEDA'),
                  subtitle: Text('v1.0.0'),
                ),
                ListTile(
                  leading: Icon(Icons.code),
                  title: Text('Open Source (MIT)'),
                  subtitle: Text('github.com/FarrelGhozy/andromeda'),
                  onTap: () => launchUrl(Uri.parse('https://github.com/FarrelGhozy/andromeda')),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportData(BuildContext context) async {
    // Implementasi: fetch data, tulis CSV, simpan, share
  }
}
```

---

## Integrasi Supabase

### Inisialisasi

```dart
// lib/config/supabase_config.dart
class SupabaseConfig {
  // GANTI dengan URL dan Key project Supabase kamu!
  static const String url = 'https://your-project.supabase.co';
  static const String anonKey = 'your-anon-public-key';
}
```

### Fungsi RPC (Database Function)

```sql
-- Di Supabase SQL Editor
-- Fungsi: ambil data terbaru semua petak
CREATE OR REPLACE FUNCTION get_latest_readings()
RETURNS TABLE (
  device_id TEXT,
  moisture INTEGER,
  moisture_percent REAL,
  valve_status TEXT,
  created_at TIMESTAMPTZ
) LANGUAGE sql AS $$
  SELECT DISTINCT ON (sr.device_id)
    sr.device_id,
    sr.moisture,
    sr.moisture_percent,
    sr.valve_status,
    sr.created_at
  FROM sensor_readings sr
  ORDER BY sr.device_id, sr.created_at DESC;
$$;
```

### Query Patterns Lengkap

```dart
// === LISTEN (Realtime) ===
// 1. Daftar device
_db.from('devices').stream(primaryKey: ['id']).order('id');

// 2. Data sensor terbaru 1 petak
_db.from('sensor_readings')
  .stream(primaryKey: ['id'])
  .eq('device_id', deviceId)
  .order('created_at', ascending: false)
  .limit(1);

// 3. Konfigurasi 1 petak
_db.from('system_config')
  .stream(primaryKey: ['id'])
  .eq('device_id', deviceId)
  .limit(1);

// === READ (One-shot) ===
// 4. History chart
_db.from('sensor_readings')
  .select()
  .eq('device_id', deviceId)
  .gte('created_at', since)
  .lte('created_at', until)
  .order('created_at');

// 5. Semua device
_db.from('devices').select().order('id');

// === WRITE ===
// 6. Insert command
_db.from('pending_commands').insert({
  'device_id': deviceId,
  'command': 'VALVE_ON',
  'duration': 30,
  'status': 'pending',
  'source': 'android',
});

// === UPDATE ===
// 7. Update config
_db.from('system_config')
  .update({'mode': 'auto', 'threshold_dry': 30})
  .eq('device_id', deviceId);
```

---

## Pengujian

### Unit Test — Model

```dart
// test/models/sensor_reading_test.dart
void main() {
  group('SensorReading', () {
    test('fromJson parsing correct', () {
      final json = {
        'id': 1,
        'device_id': 'petak-01',
        'moisture': 2200,
        'moisture_percent': 42.5,
        'valve_status': 'OFF',
        'created_at': '2026-07-18T10:00:00Z',
      };

      final reading = SensorReading.fromJson(json);

      expect(reading.id, 1);
      expect(reading.deviceId, 'petak-01');
      expect(reading.moisturePercent, 42.5);
      expect(reading.isDry(30), false);
      expect(reading.isWet(70), false);
    });

    test('isDry returns true when below threshold', () {
      final reading = SensorReading(
        id: 1,
        deviceId: 'petak-01',
        moisture: 2700,
        moisturePercent: 22.0,
        valveStatus: 'OFF',
        createdAt: DateTime.now(),
      );
      expect(reading.isDry(30), true);
    });
  });
}
```

### Unit Test — Provider

```dart
// test/providers/dashboard_provider_test.dart
void main() {
  group('DashboardProvider', () {
    late MockSensorRepository mockSensorRepo;
    late MockConfigRepository mockConfigRepo;
    late DashboardProvider provider;

    setUp(() {
      mockSensorRepo = MockSensorRepository();
      mockConfigRepo = MockConfigRepository();
      provider = DashboardProvider(mockSensorRepo, mockConfigRepo);
    });

    test('initial state is loading', () {
      expect(provider.state, DashboardState.loading);
    });

    test('loadDevice sets state to ready on success', () async {
      // Mock streams
      when(mockSensorRepo.getSensorStream('petak-01', limit: 1))
          .thenAnswer((_) => Stream.value([]));
      when(mockConfigRepo.getConfigStream('petak-01'))
          .thenAnswer((_) => Stream.value(null));

      await provider.loadDevice('petak-01');

      expect(provider.state, DashboardState.ready);
      expect(provider.deviceId, 'petak-01');
    });
  });
}
```

### Widget Test

```dart
// test/widget_test.dart
void main() {
  testWidgets('Splash screen shows logo and loading', (tester) async {
    await tester.pumpWidget(App());

    // Logo ANDROMEDA
    expect(find.text('ANDROMEDA'), findsOneWidget);
    
    // Loading indicator
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
```

### Skenario Uji Manual Aplikasi

| # | Skenario | Langkah | Hasil |
|:-:|----------|---------|-------|
| **A1** | Buka aplikasi | Tap icon ANDROMEDA | Splash → Home dalam 3 detik |
| **A2** | Lihat daftar petak | Buka Home | 6 kartu petak muncul |
| **A3** | Data realtime | Tunggu 30 detik | Data sensor update otomatis |
| **A4** | Buka valve manual | Tap BUKA → pilih 15 detik | "Perintah terkirim" ✅ |
| **A5** | Tutup valve | Tap TUTUP | Valve tertutup di status |
| **A6** | Lihat grafik | Ganti ke 7H | Chart 7 hari muncul |
| **A7** | Ubah threshold | Geser slider | Konfigurasi tersimpan |
| **A8** | Ganti mode | Tap Manual | Mode berubah di card |
| **A9** | Settings | Buka settings | Halaman settings tampil |
| **A10** | Ekspor CSV | Tap ekspor | File CSV tersimpan |
| **A11** | Rotate HP | Putar landscape | Layout rapi (responsif) |
| **A12** | Offline | Matikan internet | Banner "Tidak terhubung" |

---

## Build & Deploy

### Build APK (Android)

```bash
# Development build (debug)
flutter build apk --debug

# Production build (release)
flutter build apk --release --split-per-abi

# Atau bundle untuk Play Store
flutter build appbundle --release

# Output:
# build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
# build/app/outputs/bundle/release/app-release.aab
```

### Build AAB (Play Store)

```bash
# Pastikan keystore sudah diatur di android/key.properties
flutter build appbundle --release

# Keystore setup (android/key.properties):
# storePassword=andromeda123
# keyPassword=andromeda123
# keyAlias=andromeda
# storeFile=../keystore/andromeda.jks
```

### Konfigurasi Android

```xml
<!-- android/app/src/main/AndroidManifest.xml -->
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"
    android:maxSdkVersion="28"/>

<application
    android:label="ANDROMEDA"
    android:name="${applicationName}"
    android:icon="@mipmap/ic_launcher">
    
    <!-- Biarkan orientasi portrait agar UI konsisten -->
    <activity
        android:resizeableActivity="true"
        android:supportsPictureInPicture="false"
        android:windowSoftInputMode="adjustResize">
    </activity>
</application>
```

### Versioning

```yaml
# pubspec.yaml
version: 1.0.0+1
# Format: major.minor.patch+build
# 1.0.0+1 = rilis pertama
# 1.0.1+2 = patch bugfix
# 1.1.0+3 = fitur baru
```

### Minimum Requirements

| Platform | Minimum | Target |
|----------|:-------:|:------:|
| Android | API 21 (Android 5.0) | API 26+ (Android 8.0+) |
| RAM | 2 GB | 3 GB+ |
| Storage | 50 MB | 100 MB |
| Internet | 4G / WiFi | 4G / WiFi |

---

## Daftar Tugas Implementasi

### Fase 1 — Setup Project (1 Hari)

```
[  ] 1.1 Buat project Flutter baru
     flutter create --org com.andromeda andromeda_app

[  ] 1.2 Setup folder structure (lib/models, services, providers, etc.)

[  ] 1.3 Tambah dependencies di pubspec.yaml

[  ] 1.4 Setup Supabase project & copy URL/key

[  ] 1.5 Atur tema warna & font di theme_config.dart

[  ] 1.6 Setup routing di app.dart
```

### Fase 2 — Model & Services (1 Hari)

```
[  ] 2.1 Buat model Device
[  ] 2.2 Buat model SensorReading
[  ] 2.3 Buat model SystemConfig
[  ] 2.4 Buat model PendingCommand
[  ] 2.5 Buat SupabaseService (init + check connection)
[  ] 2.6 Buat DeviceRepository
[  ] 2.7 Buat SensorRepository
[  ] 2.8 Buat ConfigRepository
```

### Fase 3 — State Management (1 Hari)

```
[  ] 3.1 Buat DevicesProvider
[  ] 3.2 Buat DashboardProvider
[  ] 3.3 Buat ConfigProvider
[  ] 3.4 Setup MultiProvider di main.dart
```

### Fase 4 — Halaman Utama (2 Hari)

```
[  ] 4.1 SplashScreen (logo + loading + init)
[  ] 4.2 HomeScreen (daftar petak)
[  ] 4.3 DeviceCard widget
[  ] 4.4 MoistureGauge widget (custom painter)
[  ] 4.5 StatusBadge widget
```

### Fase 5 — Dashboard (2 Hari)

```
[  ] 5.1 DashboardScreen layout
[  ] 5.2 Bagian gauge kelembaban
[  ] 5.3 Bagian status valve
[  ] 5.4 Bagian kontrol valve (ValveButton)
[  ] 5.5 DurationPicker widget
[  ] 5.6 MoistureChart widget (fl_chart)
[  ] 5.7 Bagian konfigurasi (ConfigSlider)
```

### Fase 6 — Settings & Finishing (1 Hari)

```
[  ] 6.1 SettingsScreen
[  ] 6.2 Status koneksi
[  ] 6.3 Ekspor CSV
[  ] 6.4 Halaman Tentang
[  ] 6.5 Error handling (ErrorBanner)
[  ] 6.6 Loading state (shimmer/overlay)
[  ] 6.7 Refresh control
```

### Fase 7 — Testing (1 Hari)

```
[  ] 7.1 Unit test model
[  ] 7.2 Unit test provider
[  ] 7.3 Widget test
[  ] 7.4 Manual test di HP real (6 petak)
[  ] 7.5 Test offline mode
[  ] 7.6 Test rotasi/resize
```

### Prioritas Implementasi

```
MUST HAVE (MVP — Wajib):
  ■ SplashScreen ✅
  ■ HomeScreen — daftar petak ✅
  ■ DashboardScreen — gauge + valve control ✅
  ■ MoistureChart — grafik historis ✅
  ■ Config — threshold + mode ✅
  ■ Realtime update ✅
  ■ Error handling ✅

SHOULD HAVE:
  □ Ekspor CSV
  □ Settings screen lengkap
  □ Dark mode
  □ Shimmer loading

NICE TO HAVE:
  □ Notifikasi push
  □ Multiple bahasa
  □ Widget Android
  □ Landscape mode optimal
```

---

## Catatan Penting

### State Management — Mengapa Pakai Provider?

| Kriteria | Provider | BLoC | Riverpod | GetX |
|----------|:--------:|:----:|:--------:|:----:|
| Mudah dipelajari | ✅✅✅ | ⚠️⚠️ | ✅✅ | ✅✅✅ |
| Cocok untuk scope ini | ✅✅ | ⚠️⚠️ | ✅✅ | ✅⚠️ |
| Best practice Flutter | ✅✅✅ | ✅✅✅ | ✅✅✅ | ⚠️ |
| Testing mudah | ✅✅ | ✅✅✅ | ✅✅✅ | ⚠️ |
| Performa | ✅✅✅ | ✅✅✅ | ✅✅✅ | ✅✅ |

> **Kesimpulan:** Provider dipilih karena **sederhana**, **cukup untuk 6 petak**, dan **sudah jadi standar Flutter**. Kalau aplikasi membesar nanti (100+ petak), migrasi ke BLoC atau Riverpod.

### Tips Performa

1. **Gunakan `const` constructor** di semua widget statis
2. **Hindari rebuild** dengan `Consumer` spesifik (bukan `context.watch`)
3. **Batasi data chart** — maks 500 titik data
4. **Cache gambar** dengan `cached_network_image`
5. **Kompresi JSON** — pakai `select('column1,column2')` jangan `select(*)`
6. **Debounce** slider config — jangan update ke Supabase tiap geser

### Keamanan

1. **Hanya pakai anon key** — jangan pakai service_role key di aplikasi
2. **RLS aktif** — pastikan policy PUBLIC sudah benar
3. **Jangan hardcode rahasia** — pakai `.env` atau `--dart-define`
4. **Input validation** — validasi threshold dry < wet

---

## Referensi

### Library Documentation

| Library | Link |
|---------|------|
| supabase_flutter | [pub.dev/packages/supabase_flutter](https://pub.dev/packages/supabase_flutter) |
| provider | [pub.dev/packages/provider](https://pub.dev/packages/provider) |
| fl_chart | [pub.dev/packages/fl_chart](https://pub.dev/packages/fl_chart) |
| google_fonts | [pub.dev/packages/google_fonts](https://pub.dev/packages/google_fonts) |
| shimmer | [pub.dev/packages/shimmer](https://pub.dev/packages/shimmer) |

### Supabase Docs

| Topik | Link |
|-------|------|
| Flutter SDK Quickstart | [supabase.com/docs/reference/dart/start](https://supabase.com/docs/reference/dart/start) |
| Realtime Subscriptions | [supabase.com/docs/reference/dart/subscribe](https://supabase.com/docs/reference/dart/subscribe) |
| Row Level Security | [supabase.com/docs/guides/auth/row-level-security](https://supabase.com/docs/guides/auth/row-level-security) |

---

> 🌾 *ANDROMEDA — Dari petani, oleh petani, untuk petani.*
> 
> *Dokumen ini adalah cetak biru teknis untuk membangun aplikasi Flutter ANDROMEDA.*
> *Ikuti daftar tugas di Fase 1-7 untuk implementasi langkah demi langkah.*
