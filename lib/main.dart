import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_api.dart';
import 'auth_screen.dart';
import 'cloud_api.dart';
import 'cloud_home.dart';
import 'cloud_theme.dart';
import 'supabase_cloud_api.dart';
export 'cloud_theme.dart' show cloudTheme;
export 'cloud_home.dart' show CloudClubHome;

const _supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://ygbhwfgziovxoeijcxfn.supabase.co',
);
const _supabasePublishableKey = String.fromEnvironment(
  'SUPABASE_PUBLISHABLE_KEY',
  defaultValue: 'sb_publishable_Nc77kfb6FtVzB9AMQLOM4A_ApkhF3G5',
);
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: _supabaseUrl,
    publishableKey: _supabasePublishableKey,
  );
  runApp(const CloudClubApp(useSupabase: true));
}

class CloudClubApp extends StatelessWidget {
  const CloudClubApp({
    super.key,
    this.authApi,
    this.cloudApiBuilder,
    this.useSupabase = false,
  });
  final AuthApi? authApi;
  final CloudApi Function(String token)? cloudApiBuilder;
  final bool useSupabase;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Cloud Club',
    debugShowCheckedModeBanner: false,
    theme: cloudTheme(),
    home: AuthGate(
      api: authApi ?? (useSupabase ? SupabaseAuthApi() : null),
      signedInBuilder: (session, logout) => CloudClubHome(
        key: ValueKey(session.token),
        name: session.name,
        onLogout: logout,
        api:
            cloudApiBuilder?.call(session.token) ??
            (useSupabase
                ? SupabaseCloudApi(session.token)
                : CloudApi(session.token)),
      ),
    ),
  );
}
