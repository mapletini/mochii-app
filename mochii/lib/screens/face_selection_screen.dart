import 'package:flutter/material.dart';

import '../state/app_face.dart';

class FaceSelectionScreen extends StatelessWidget {
  const FaceSelectionScreen({required this.onSelectFace, super.key});

  final Future<void> Function(AppFace face) onSelectFace;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Choose Face')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text(
              'Digital Collar: Dual Faced',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            const Text(
              'Pick the mode for this device. You can switch later.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => onSelectFace(AppFace.puppy),
              child: const Text('Puppy Face'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => onSelectFace(AppFace.handler),
              child: const Text('Handler Face'),
            ),
          ],
        ),
      ),
    );
  }
}
