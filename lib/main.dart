import 'package:flutter/material.dart';

import 'auth_api.dart';
import 'auth_screen.dart';
import 'cloud_api.dart';
import 'cloud_home.dart';
import 'cloud_theme.dart';
export 'cloud_theme.dart' show cloudTheme;
export 'cloud_home.dart' show CloudClubHome;

void main() => runApp(const CloudClubApp());

class CloudClubApp extends StatelessWidget {
  const CloudClubApp({super.key, this.authApi, this.cloudApiBuilder});
  final AuthApi? authApi;
  final CloudApi Function(String token)? cloudApiBuilder;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Cloud Club',
    debugShowCheckedModeBanner: false,
    theme: cloudTheme(),
    home: AuthGate(
      api: authApi,
      signedInBuilder: (session, logout) => CloudClubHome(
        key: ValueKey(session.token),
        name: session.name,
        onLogout: logout,
        api: cloudApiBuilder?.call(session.token) ?? CloudApi(session.token),
      ),
    ),
  );
}
