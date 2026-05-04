# live_photo_capture

A Flutter package for face liveness detection with configurable challenge types and auto-capture. Detect real human presence — not a photo, video, or mask — using challenges like smile, blink, and head turns, with animated visual feedback and built-in photo capture on success.

## Features

- Real-time face detection via Google ML Kit
- Configurable liveness rule set: smile, blink, look left/right, tilt up/down
- Animated dotted-circle progress indicator around the face frame
- Auto face-centering guidance
- Captures a photo after all liveness rules are passed
- Customizable colors, sizes, and UI overlays

## Platform Support

| Android | iOS |
|:-------:|:---:|
| ✅      | ✅  |

### Permissions

Add the following to your platform manifests:

**Android** — `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.CAMERA" />
```

**iOS** — `ios/Runner/Info.plist`:
```xml
<key>NSCameraUsageDescription</key>
<string>This app uses the camera for liveness detection.</string>
```

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  live_photo_capture: ^0.0.1
```

Then run:
```sh
flutter pub get
```

## Usage

```dart
import 'package:live_photo_capture/livephotocapture.dart';

FaceDetectorScreen(
  // Called each time a liveness rule is completed
  onRulesetCompleted: (ruleset) {
    print('Completed: $ruleset');
  },
  // Called when all rules pass; provides the CameraController for capture
  onValidationDone: (controller) {
    return ElevatedButton(
      onPressed: () async {
        final photo = await controller?.takePicture();
        // handle photo
      },
      child: const Text('Capture'),
    );
  },
  // Builder for the overlay shown during liveness checks
  child: ({required state, required countdown, required hasFace}) {
    return Text(
      hasFace ? 'Hold still... $countdown' : 'Place your face in frame',
      style: const TextStyle(color: Colors.white, fontSize: 18),
    );
  },
);
```

## Customisation

| Parameter | Type | Description |
|---|---|---|
| `ruleset` | `List<Rulesets>` | Ordered list of liveness checks to perform |
| `progressColor` | `Color` | Inactive dot color |
| `activeProgressColor` | `Color` | Active/completed dot color |
| `totalDots` | `int` | Number of dots in the circle |
| `dotRadius` | `double` | Radius of each dot |
| `cameraSize` | `Size` | Size of the camera preview frame |
| `pauseDurationInSeconds` | `int` | Pause between ruleset steps |
| `backgroundColor` | `Color?` | Background color of the detector |
| `contextPadding` | `EdgeInsetsGeometry?` | Padding around the content |

### Available Rulesets

```dart
enum Rulesets { toLeft, toRight, blink, tiltUp, tiltDown, smiling, normal }
```

## License

MIT
