import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/services.dart';
import 'core/theme.dart';
import 'screens/auth/login_screen.dart';
import 'screens/shell/main_shell.dart';
import 'state/auth_controller.dart';

class CineBookApp extends StatefulWidget {
  const CineBookApp({super.key});
  @override
  State<CineBookApp> createState() => _CineBookAppState();
}

class _CineBookAppState extends State<CineBookApp> {
  late final AppServices _services;
  late final AuthController _auth;

  @override
  void initState() {
    super.initState();
    _services = AppServices.build();
    _auth = AuthController(_services.auth, _services.tokens);
    //A rejected refresh token bounces the user back to login.
    _services.api.onSessionExpired = _auth.onSessionExpired;
    _auth.bootstrap();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AppServices>.value(value: _services),
        ChangeNotifierProvider<AuthController>.value(value: _auth),
      ],
      child: MaterialApp(
        title: 'CineBook',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: const _AuthGate(),
      ),
    );
  }
}

//Routes between the splash, login, and the authenticated shell.
class _AuthGate extends StatelessWidget {
  const _AuthGate();
  @override
  Widget build(BuildContext context) {
    final status = context.watch<AuthController>().status;
    final child = switch (status) {
      AuthStatus.unknown => const _Splash(),
      AuthStatus.unauthenticated => const LoginScreen(),
      AuthStatus.authenticated => const MainShell(),
    };
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      child: KeyedSubtree(key: ValueKey(status), child: child),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'CineBook',
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
