import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../utils/currency_formatter.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  /// Inisialisasi dan wajib tanyakan izin notifikasi kepada pengguna
  Future<void> init() async {
    try {
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings initializationSettingsDarwin =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const InitializationSettings initializationSettings =
          InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsDarwin,
      );

      await _notificationsPlugin.initialize(
        initializationSettings,
      );

      // Wajib tampilkan dialog izin notifikasi untuk Android 13 ke atas
      final androidImplementation =
          _notificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        await androidImplementation.requestNotificationsPermission();
      }
    } catch (e) {
      // Menggunakan print aman di production
      // ignore: avoid_print
      print('Error initializing NotificationService: $e');
    }
  }

  /// Memunculkan notifikasi lokal setelah sukses menambah saldo
  Future<void> showTopupNotification({
    required double amount,
    required double balance,
  }) async {
    final formattedAmount = CurrencyFormatter.format(amount);
    final formattedBalance = CurrencyFormatter.format(balance);

    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
      'topup_channel', // channel id
      'Top Up Saldo', // channel name
      channelDescription: 'Notifikasi ketika berhasil mengisi saldo Uang Kilat',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    );

    const DarwinNotificationDetails iosNotificationDetails =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
      iOS: iosNotificationDetails,
    );

    await _notificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'Top Up Berhasil! ⚡',
      'Isi saldo sebesar $formattedAmount sukses. Saldo Uang Kilat kamu sekarang: $formattedBalance.',
      notificationDetails,
    );
  }
}
