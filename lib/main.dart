import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'core/api/api_client.dart';
import 'core/api/token_storage.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/register_screen.dart';
import 'features/shell/home_shell.dart';
import 'repositories/repositories.dart';
import 'state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Azərbaycan dilində tarix formatlaması üçün.
  await initializeDateFormatting('az');
  await TokenStorage.instance.load();

  runApp(const BookingApp());
}

class BookingApp extends StatelessWidget {
  const BookingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthController(const AuthRepository())..restore(),
        ),
        ChangeNotifierProvider(
          create: (_) => NotificationController(const NotificationRepository()),
        ),
      ],
      child: MaterialApp(
        title: 'Randevu — onlayn bron',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        home: const _Root(),
      ),
    );
  }
}

/// Sessiyaya görə login və ya ana ekranı göstərir.
class _Root extends StatefulWidget {
  const _Root();

  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  /// Sessiya yoxdursa login yoxsa qeydiyyat gosterilsin?
  bool _showRegister = false;

  @override
  void initState() {
    super.initState();

    // Refresh alınmayanda interceptor bunu çağırır və tətbiq login-ə qayıdır.
    ApiClient.instance.onUnauthorized = () {
      if (mounted) context.read<AuthController>().onSessionExpired();
    };
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final claims = auth.claims;

    if (claims == null) {
      return _showRegister
          ? RegisterScreen(
              onShowLogin: () => setState(() => _showRegister = false),
            )
          : LoginScreen(
              onShowRegister: () => setState(() => _showRegister = true),
            );
    }

    // BookingController rola bağlıdır — rol dəyişəndə yenisi qurulmalıdır,
    // ona görə key kimi userId + rol verilir.
    return ChangeNotifierProvider<BookingController>(
      key: ValueKey('${claims.userId}-${claims.role}'),
      create: (_) => BookingController(
        const BookingRepository(),
        isProvider: claims.isProvider,
      ),
      child: HomeShell(claims: claims),
    );
  }
}
