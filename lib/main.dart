import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'app/theme/app_theme.dart';
import 'app/routes.dart';
import 'providers/wallet_provider.dart';
import 'widgets/auth_guard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  
  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  runApp(const GringottsWalletApp());
}

class GringottsWalletApp extends StatelessWidget {
  const GringottsWalletApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AuthGuard(
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (context) => WalletProvider(),
          ),
        ],
        child: MaterialApp(
          title: 'Gringotts Wallet',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.darkTheme,
          themeMode: ThemeMode.dark,
          initialRoute: AppRoutes.splash,
          onGenerateRoute: AppRoutes.generateRoute,
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(1.0), // Prevent text scaling
              ),
              child: child!,
            );
          },
        ),
      ),
    );
  }
}
