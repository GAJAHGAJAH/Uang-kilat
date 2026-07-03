import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';

/// Service untuk mengelola autentikasi biometrik.
///
/// Flow:
/// - Biometrik aktif secara default saat user pertama kali login (jika hardware mendukung).
/// - Saat user logout, flag dimatikan sehingga biometrik tidak muncul di splash.
/// - Saat app resume dari background (minimized), biometrik ditrigger jika flag aktif.
class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();

  /// Cek apakah hardware biometrik tersedia dan sudah terdaftar.
  Future<bool> isAvailable() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isDeviceSupported = await _auth.isDeviceSupported();
      if (!canCheck || !isDeviceSupported) return false;
      final biometrics = await _auth.getAvailableBiometrics();
      return biometrics.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Cek apakah biometrik diaktifkan oleh user di SharedPreferences.
  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    // Default false — diaktifkan saat user berhasil login pertama kali.
    return prefs.getBool(AppConstants.kBiometricEnabled) ?? false;
  }

  /// Aktifkan biometrik (dipanggil setelah login + 2FA berhasil).
  Future<void> enable() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.kBiometricEnabled, true);
  }

  /// Nonaktifkan biometrik (dipanggil saat user logout).
  Future<void> disable() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.kBiometricEnabled, false);
  }

  /// Tampilkan prompt biometrik ke user.
  /// Mengembalikan `true` jika autentikasi berhasil.
  Future<bool> authenticate({String reason = 'Verifikasi identitas Anda untuk masuk ke Uang Kilat'}) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,       // Tetap tunggu bahkan jika app di-background sebentar
          biometricOnly: false,   // Izinkan fallback ke PIN device jika biometrik gagal
          sensitiveTransaction: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }

  /// Dapatkan list tipe biometrik yang tersedia (fingerprint / face).
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } catch (_) {
      return [];
    }
  }

  /// Hentikan autentikasi yang sedang berlangsung (misal: saat app di-stop).
  Future<void> stopAuthentication() async {
    try {
      await _auth.stopAuthentication();
    } catch (_) {}
  }
}
