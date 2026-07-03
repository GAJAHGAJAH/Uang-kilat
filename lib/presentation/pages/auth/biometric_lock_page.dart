import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';
import '../../../core/services/biometric_service.dart';
import '../../../core/services/deeplink_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../widgets/app_logo.dart';

/// Layar kunci biometrik — muncul saat app resume dari background
/// dan user sudah login sebelumnya (biometrik diaktifkan).
///
/// User TIDAK dapat menutup layar ini tanpa autentikasi.
/// Jika biometrik tidak tersedia, user bisa fallback ke PIN device.
class BiometricLockPage extends StatefulWidget {
  const BiometricLockPage({super.key});

  @override
  State<BiometricLockPage> createState() => _BiometricLockPageState();
}

class _BiometricLockPageState extends State<BiometricLockPage>
    with SingleTickerProviderStateMixin {
  final _biometricService = BiometricService();
  bool _isAuthenticating = false;
  bool _hasFailed = false;
  String? _errorMsg;
  List<BiometricType> _biometrics = [];

  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1600),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _loadBiometrics();
    // Langsung minta autentikasi saat layar muncul
    WidgetsBinding.instance.addPostFrameCallback((_) => _authenticate());
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadBiometrics() async {
    final types = await _biometricService.getAvailableBiometrics();
    if (mounted) setState(() => _biometrics = types);
  }

  Future<void> _authenticate() async {
    if (_isAuthenticating) return;
    setState(() {
      _isAuthenticating = true;
      _hasFailed = false;
      _errorMsg = null;
    });

    final success = await _biometricService.authenticate();

    if (!mounted) return;

    if (success) {
      _onSuccess();
    } else {
      setState(() {
        _isAuthenticating = false;
        _hasFailed = true;
        _errorMsg = 'Autentikasi gagal. Coba lagi.';
      });
    }
  }

  void _onSuccess() {
    final pending = DeeplinkService.consumePending();
    if (pending != null) {
      context.go('/pay', extra: pending);
    } else {
      context.go('/home');
    }
  }

  IconData get _biometricIcon {
    if (_biometrics.contains(BiometricType.face)) return Icons.face_unlock_rounded;
    if (_biometrics.contains(BiometricType.iris)) return Icons.remove_red_eye_rounded;
    return Icons.fingerprint_rounded;
  }

  String get _biometricLabel {
    if (_biometrics.contains(BiometricType.face)) return 'Face ID';
    if (_biometrics.contains(BiometricType.iris)) return 'Iris';
    return 'Sidik Jari';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        // Scaffold harus transparan agar gradient di Container terlihat di balik status bar
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        body: Container(
          // Gradient menutupi SELURUH layar termasuk area status bar
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
          child: SafeArea(
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height -
                      MediaQuery.of(context).padding.top -
                      MediaQuery.of(context).padding.bottom,
                ),
                child: Stack(
                  children: [
                    // Dekoratif lingkaran atas
                    Positioned(
                      top: -80,
                      right: -60,
                      child: Container(
                        width: 260,
                        height: 260,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.06),
                        ),
                      ),
                    ),
                    // Dekoratif lingkaran bawah
                    Positioned(
                      bottom: 160,
                      left: -80,
                      child: Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.05),
                        ),
                      ),
                    ),
                    // Konten utama
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        children: [
                          const SizedBox(height: 60),

                          // Logo
                          const AppLogo(size: 72, light: true),
                          const SizedBox(height: 20),
                          const Text(
                            'Uang Kilat',
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Verifikasi identitas Anda untuk melanjutkan',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 14,
                              color: Colors.white70,
                              height: 1.4,
                            ),
                          ),

                          const SizedBox(height: 80),

                          // Tombol biometrik dengan animasi pulse
                          GestureDetector(
                            onTap: _isAuthenticating ? null : _authenticate,
                            child: Column(
                              children: [
                                AnimatedBuilder(
                                  animation: _pulseAnim,
                                  builder: (_, child) => Transform.scale(
                                    scale: _isAuthenticating ? _pulseAnim.value : 1.0,
                                    child: child,
                                  ),
                                  child: Container(
                                    width: 110,
                                    height: 110,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white.withOpacity(0.15),
                                      border: Border.all(
                                        color: _hasFailed
                                            ? Colors.redAccent.withOpacity(0.8)
                                            : Colors.white.withOpacity(0.35),
                                        width: 2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.2),
                                          blurRadius: 30,
                                          spreadRadius: 5,
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      _biometricIcon,
                                      size: 54,
                                      color: _hasFailed
                                          ? Colors.redAccent
                                          : Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 18),
                                Text(
                                  _isAuthenticating
                                      ? 'Menunggu $_biometricLabel...'
                                      : 'Ketuk untuk $_biometricLabel',
                                  style: TextStyle(
                                    fontFamily: 'PlusJakartaSans',
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white.withOpacity(0.9),
                                  ),
                                ),
                                if (_errorMsg != null) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    _errorMsg!,
                                    style: const TextStyle(
                                      fontFamily: 'PlusJakartaSans',
                                      fontSize: 13,
                                      color: Colors.redAccent,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),

                          const SizedBox(height: 60),

                          // Tombol coba lagi (muncul setelah gagal)
                          if (_hasFailed) _buildRetryButton(),

                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRetryButton() {
    return Column(
      children: [
        GestureDetector(
          onTap: _authenticate,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Text(
              'Coba Lagi',
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}
