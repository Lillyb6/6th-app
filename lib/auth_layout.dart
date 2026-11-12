import 'package:material_ui/material_ui.dart';

import 'cloud_widgets.dart';
import 'cloud_theme.dart';

class AuthLayout extends StatelessWidget {
  const AuthLayout({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: cloudGround,
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, c) {
          final wide = c.maxWidth >= 900;
          final form = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.all(28),
                child: CloudWordmark(),
              ),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: child,
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(28, 12, 28, 24),
                child: Text(
                  'A place for people with their heads in the clouds.',
                  style: TextStyle(color: cloudMuted, fontSize: 12),
                ),
              ),
            ],
          );
          return Row(
            children: [
              if (wide)
                Expanded(
                  flex: 6,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.asset(
                            'assets/blue-sky-background-clouds.webp',
                            fit: BoxFit.cover,
                          ),
                          Align(
                            alignment: Alignment.topLeft,
                            child: Padding(
                              padding: const EdgeInsets.all(40),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    'An ordinary sky.\nAn extraordinary pause.',
                                    style: TextStyle(
                                      fontFamily: 'Instrument Serif',
                                      fontSize: 48,
                                      height: 1.05,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  Container(
                                    constraints: const BoxConstraints(
                                      maxWidth: 300,
                                    ),
                                    child: const Text(
                                      'Catch a cloud. Share what you see.\nFind someone who sees it, too.',
                                      style: TextStyle(
                                        fontSize: 15,
                                        height: 1.6,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            left: 24,
                            right: 24,
                            bottom: 24,
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.cloud_outlined, color: cloudInk),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Same sky. A thousand different daydreams.',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: cloudInk,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              Expanded(
                flex: 5,
                child: ColoredBox(color: Colors.white, child: form),
              ),
            ],
          );
        },
      ),
    ),
  );
}
