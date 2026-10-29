import 'package:flutter/material.dart';

void main() => runApp(const CloudClubApp());

class CloudClubApp extends StatelessWidget {
  const CloudClubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cloud Club',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF397FA3)),
        scaffoldBackgroundColor: const Color(0xFFF0F7FC),
      ),
      home: const CloudClubHome(),
    );
  }
}

class CloudClubHome extends StatelessWidget {
  const CloudClubHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cloud Club')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Icon(
              Icons.cloud_outlined,
              size: 100,
              color: Color(0xFF397FA3),
            ),
            const SizedBox(height: 24),
            Text(
              'What do you see?',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 12),
            const Text(
              'A dog? A dragon? A whole new world? Capture a cloud and let your imagination wander.',
            ),
            const SizedBox(height: 28),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Your next cloud adventure'),
                    SizedBox(height: 16),
                    Text('1. Capture or upload a cloud'),
                    SizedBox(height: 12),
                    Text('2. Guess its shape and reveal the AI suggestion'),
                    SizedBox(height: 12),
                    Text('3. Share and compare with friends'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Photo capture and AI interpretations are coming next. This is the Cloud Club starting screen.',
            ),
          ],
        ),
      ),
    );
  }
}
