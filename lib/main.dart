import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/router/app_router.dart';
import 'core/services/biometric_service.dart';
import 'core/services/deeplink_service.dart';
import 'core/services/notification_service.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/app_bloc_observer.dart';
import 'injection/injection_container.dart' as di;

// Top-level variable — mencegah DeeplinkService di-garbage collect selama
// proses berjalan sehingga uriLinkStream tetap aktif untuk in-app deeplinks.
late final DeeplinkService _deeplinkService;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Bloc.observer = const AppBlocObserver();

  // Initialize Firebase — pastikan google-services.json/GoogleService-Info.plist sudah ada
  await Firebase.initializeApp();

  // Initialize dependency injection
  await di.init();

  // Inisialisasi layanan notifikasi lokal dan minta izin perizinan
  await NotificationService().init();

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Status bar style
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  // Simpan instance agar tidak di-GC — stream subscription harus tetap hidup
  // untuk menerima in-app deeplinks via onNewIntent (Android singleTop).
  _deeplinkService = DeeplinkService(AppRouter.router);
  await _deeplinkService.init();

  runApp(const UangKilatApp());
}

class UangKilatApp extends StatefulWidget {
  const UangKilatApp({super.key});

  @override
  State<UangKilatApp> createState() => _UangKilatAppState();
}

class _UangKilatAppState extends State<UangKilatApp> {
  final _biometricService = BiometricService();
  late final AppLifecycleListener _lifecycleListener;

  /// Flag: app benar-benar ke background (bukan hanya inactive karena dialog sistem).
  bool _isInBackground = false;

  /// Flag: sedang di halaman biometric lock, hindari double redirect.
  bool _isOnBiometricLock = false;

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(
      // onHide = app benar-benar tersembunyi ke background (bukan sekedar dialog overlay)
      onHide: _onHide,
      onResume: _onResume,
      // onShow dipanggil saat app kembali visible, dipakai untuk reset flag
      onShow: () => _isOnBiometricLock = false,
    );
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

  /// Dipanggil saat app BENAR-BENAR pindah ke background.
  /// Tandai bahwa biometrik harus ditrigger saat resume.
  Future<void> _onHide() async {
    final enabled = await _biometricService.isEnabled();
    if (enabled) {
      _isInBackground = true;
    }
  }

  /// Dipanggil saat app kembali ke foreground.
  /// Jika flag background aktif, redirect ke BiometricLockPage.
  Future<void> _onResume() async {
    if (!_isInBackground) return;
    _isInBackground = false;

    // Hindari double-redirect jika sudah di biometric lock page
    if (_isOnBiometricLock) return;

    final enabled = await _biometricService.isEnabled();
    if (!enabled) return;

    final available = await _biometricService.isAvailable();
    if (!available) return;

    // Navigasi ke layar lock biometrik
    _isOnBiometricLock = true;
    // ignore: use_build_context_synchronously
    AppRouter.router.go('/biometric-lock');
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Uang Kilat',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: AppRouter.router,
    );
  }
}
