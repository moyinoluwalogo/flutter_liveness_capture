import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:liveness_capture/liveness_capture.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Live Photo Capture Demo',
      theme: ThemeData(colorSchemeSeed: Colors.indigo),
      home: const LivenessPage(),
    );
  }
}

class LivenessPage extends StatelessWidget {
  const LivenessPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Liveness Check')),
      body: FaceDetectorScreen(
        ruleset: const [
          Rulesets.normal,
          Rulesets.smiling,
          Rulesets.blink,
          Rulesets.toLeft,
          Rulesets.toRight,
        ],
        activeProgressColor: Colors.green,
        progressColor: Colors.grey,
        onRulesetCompleted: (ruleset) {
          debugPrint('Completed ruleset: $ruleset');
        },
        onValidationDone: (CameraController? controller) {
          return ElevatedButton(
            onPressed: () async {
              if (controller == null) return;
              final photo = await controller.takePicture();
              debugPrint('Photo saved to: ${photo.path}');
            },
            child: const Text('Take Photo'),
          );
        },
        child: ({required state, required countdown, required hasFace}) {
          String message;
          switch (state) {
            case Rulesets.smiling:
              message = 'Please smile';
            case Rulesets.blink:
              message = 'Please blink';
            case Rulesets.toLeft:
              message = 'Look left';
            case Rulesets.toRight:
              message = 'Look right';
            case Rulesets.tiltUp:
              message = 'Tilt up';
            case Rulesets.tiltDown:
              message = 'Tilt down';
            case Rulesets.normal:
              message = 'Look straight ahead';
          }
          return Text(
            hasFace ? '$message ($countdown)' : 'Place your face in frame',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          );
        },
      ),
    );
  }
}
