import 'package:flutter/material.dart';

import 'cloud_api.dart';
import 'cloud_theme.dart';

class CloudWordmark extends StatelessWidget {
  const CloudWordmark({super.key});
  @override
  Widget build(BuildContext context) => const Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(Icons.cloud_outlined, size: 28),
      SizedBox(width: 9),
      Text(
        'Cloud Club',
        style: TextStyle(
          fontSize: 21,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.7,
        ),
      ),
    ],
  );
}

class CloudAvatar extends StatelessWidget {
  const CloudAvatar({
    super.key,
    required this.name,
    this.data = '',
    this.radius = 20,
  });
  final String name, data;
  final double radius;
  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: radius,
    backgroundColor: const Color(0xFFE1EBEF),
    foregroundColor: cloudInk,
    backgroundImage: data.isEmpty ? null : MemoryImage(photoBytes(data)),
    child: data.isEmpty
        ? Text(
            name.isEmpty ? '?' : name.characters.first.toUpperCase(),
            style: TextStyle(
              fontSize: radius * .75,
              fontWeight: FontWeight.w500,
            ),
          )
        : null,
  );
}

class PhotoImage extends StatelessWidget {
  const PhotoImage(this.data, {super.key});
  final String data;
  @override
  Widget build(BuildContext context) => Image.memory(
    photoBytes(data),
    fit: BoxFit.cover,
    gaplessPlayback: true,
    errorBuilder: (_, _, _) => const ColoredBox(
      color: cloudGround,
      child: Center(child: Text('This photo could not be displayed.')),
    ),
  );
}
