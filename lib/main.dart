import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'injection.dart' as di;
import 'presentation/blocs/settings/settings_cubit.dart';
import 'presentation/pages/lock_page.dart';
import 'routes/app_router.dart';

import 'package:google_fonts/google_fonts.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  di.init();
  await initializeDateFormatting('vi_VN');
  await di.sl<SettingsCubit>().load();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final _settings = di.sl<SettingsCubit>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Khóa lại khi ứng dụng bị đưa xuống nền (nếu đã đặt mã PIN).
    if (state == AppLifecycleState.paused) _settings.lock();
  }

  ThemeData _buildTheme(BuildContext context, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF2E63FF), // Modern blue
      brightness: brightness,
      surface: isDark ? const Color(0xFF111620) : Colors.grey[50],
    );
    final base = ThemeData(brightness: brightness, useMaterial3: true);
    return ThemeData(
      colorScheme: colorScheme,
      // Material 3 dùng màu surface làm primaryColor ở chế độ tối; giữ màu xanh thương hiệu.
      primaryColor: isDark ? const Color(0xFF5B85FF) : colorScheme.primary,
      useMaterial3: true,
      textTheme: GoogleFonts.interTextTheme(base.textTheme),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _settings,
      child: BlocBuilder<SettingsCubit, SettingsState>(
        buildWhen: (a, b) => a.themeMode != b.themeMode || a.isLocked != b.isLocked,
        builder: (context, settings) {
          return MaterialApp.router(
            title: 'ChiaPay',
            debugShowCheckedModeBanner: false,
            theme: _buildTheme(context, Brightness.light),
            darkTheme: _buildTheme(context, Brightness.dark),
            themeMode: settings.themeMode,
            routerConfig: appRouter,
            locale: const Locale('vi', 'VN'),
            supportedLocales: const [Locale('vi', 'VN'), Locale('en', 'US')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            // Màn hình khóa phủ lên trên để không làm mất ngăn xếp điều hướng hiện tại.
            builder: (context, child) => Stack(
              children: [
                ?child,
                if (settings.isLocked) const Positioned.fill(child: LockPage()),
              ],
            ),
          );
        },
      ),
    );
  }
}
