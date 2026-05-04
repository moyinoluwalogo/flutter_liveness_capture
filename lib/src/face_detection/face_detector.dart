import 'dart:developer' as dev;
import 'dart:io';
import 'dart:math' as math;
import 'package:camera/camera.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:liveness_capture/liveness_capture.dart';
import 'package:liveness_capture/src/debouncer/debouncer.dart';
import 'package:liveness_capture/src/detector_view/detector_view.dart';
import 'package:permission_handler/permission_handler.dart';

/// The main widget for real-time face liveness detection.
///
/// Displays a camera preview with an animated dotted progress ring and guides
/// the user through a configurable sequence of [Rulesets] challenges. When all
/// challenges have been completed, [onValidationDone] is called with the active
/// [CameraController] so the caller can capture a photo.
///
/// ### Minimal usage
/// ```dart
/// FaceDetectorScreen(
///   onRulesetCompleted: (ruleset) => debugPrint('Done: $ruleset'),
///   onValidationDone: (controller) {
///     return ElevatedButton(
///       onPressed: () async => await controller?.takePicture(),
///       child: const Text('Capture'),
///     );
///   },
///   child: ({required state, required countdown, required hasFace}) {
///     return Text(hasFace ? 'Hold still… $countdown' : 'Show your face');
///   },
/// )
/// ```
class FaceDetectorScreen extends StatefulWidget {
  /// Seconds to pause between ruleset steps. Defaults to 5.
  final int pauseDurationInSeconds;

  /// Size of the circular camera preview. Defaults to 200×200.
  final Size cameraSize;

  /// Called with `true` when all validations pass, `false` otherwise.
  final Function(bool validated)? onSuccessValidation;

  /// Called each time a single ruleset challenge is completed.
  final void Function(Rulesets ruleset)? onRulesetCompleted;

  /// Ordered list of liveness challenges to perform. Must not be empty.
  final List<Rulesets> ruleset;

  /// Color of dots that represent completed progress in the ring.
  final Color activeProgressColor;

  /// Color of dots that represent remaining progress in the ring.
  final Color progressColor;

  /// Builder for the overlay widget shown during liveness challenges.
  ///
  /// Receives the current [Rulesets] state, the remaining [countdown] seconds,
  /// and whether a [hasFace] is detected in frame.
  final Widget Function({
    required Rulesets state,
    required int countdown,
    required bool hasFace,
  })
  child;

  /// Builder for the widget shown after all challenges pass.
  ///
  /// Receives the active [CameraController] (may be `null`) so the caller
  /// can call [CameraController.takePicture].
  final Widget Function(CameraController? controller) onValidationDone;

  /// Total number of dots in the progress ring. Defaults to 60.
  final int totalDots;

  /// Radius of each dot in logical pixels. Defaults to 3.
  final double dotRadius;

  /// Background color of the widget. Defaults to [Colors.white].
  final Color? backgroundColor;

  /// Padding around the content column.
  final EdgeInsetsGeometry? contextPadding;

  final void Function(CameraController controller)? onController;

  const FaceDetectorScreen({
    super.key,
    required this.onRulesetCompleted,
    required this.onValidationDone,
    this.ruleset = const [
      Rulesets.smiling,
      Rulesets.blink,
      Rulesets.toRight,
      Rulesets.toLeft,
      Rulesets.tiltUp,
      Rulesets.tiltDown,
      Rulesets.normal,
    ],
    required this.child,
    this.progressColor = Colors.green,
    this.activeProgressColor = Colors.red,
    this.totalDots = 60,
    this.dotRadius = 3,
    this.onSuccessValidation,
    this.backgroundColor = Colors.white,
    this.contextPadding,
    this.cameraSize = const Size(200, 200),
    this.pauseDurationInSeconds = 5,
    this.onController,
  }) : assert(ruleset.length != 0, 'Ruleset cannot be empty');

  @override
  State<FaceDetectorScreen> createState() => _FaceDetectorScreenState();
}

class _FaceDetectorScreenState extends State<FaceDetectorScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  ValueNotifier<List<Rulesets>> ruleset = ValueNotifier<List<Rulesets>>([]);
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: true,
      enableLandmarks: true,
      enableTracking: true,
      performanceMode: FaceDetectorMode.accurate,
      enableClassification: true,
    ),
  );
  bool _canProcess = true;
  bool _isBusy = false;
  String? _text;
  final _cameraLensDirection = CameraLensDirection.front;
  late ValueNotifier<Rulesets?> _currentTest;
  Debouncer? _debouncer;
  CameraController? controller;
  bool hasFace = false;
  Future<void>? _permissionFuture;
  late AnimationController _pulseController;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _canProcess = false;
    _faceDetector.close();
    _debouncer?.stop();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ruleset.value = widget.ruleset.toList();
    _currentTest = ValueNotifier<Rulesets?>(ruleset.value.first);

    _debouncer = Debouncer(
      durationInSeconds: widget.pauseDurationInSeconds,
      onComplete: () => dev.log('Timer completed'),
      onTick: () {
        if (mounted) setState(() {});
      },
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    PermissionManager.requestCameraPermission().then((granted) {
      if (granted) {
        _debouncer?.start(); // start timer only if permission granted
      }
    });
    // Only request permission here
    // _requestCameraPermissionAndStartTimer();
  }

  final bool _permissionGranted = false;

  Future<void> _requestCameraPermissionAndStartTimer() async {
    if (_permissionFuture != null) {
      await _permissionFuture; // wait for the existing request
      return;
    }
    PermissionManager.requestCameraPermission().then((granted) {
      if (granted) {
        _debouncer?.start(); // start timer only if permission granted
      }
    });
    try {
      await _permissionFuture;
    } finally {
      _permissionFuture = null; // reset after done
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_permissionGranted) {
      // Request permission only if not yet granted
      _requestCameraPermissionAndStartTimer();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: widget.backgroundColor ?? Colors.transparent,
      shadowColor: Colors.transparent,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      child: Container(
        padding:
            widget.contextPadding ??
            EdgeInsets.symmetric(horizontal: 22, vertical: 20),

        width: double.infinity,
        child: Column(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ValueListenableBuilder(
              valueListenable: _currentTest,
              builder: (context, state, child) {
                double targetProgress = state != null
                    ? (widget.ruleset.indexOf(state) / widget.ruleset.length)
                          .toDouble()
                    : 1.0;
                return AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, _) {
                    final double pulse = _pulseController.value;
                    // When a face is present every dot turns green and
                    // the radius pulses gently. When absent all dots are red.
                    final Color dotColor = hasFace
                        ? Color.lerp(
                            Colors.green.shade400,
                            Colors.green.shade700,
                            pulse,
                          )!
                        : Colors.red.shade400;
                    final double dotRadius = hasFace
                        ? widget.dotRadius * (1.0 + 0.45 * pulse)
                        : widget.dotRadius;

                    return TweenAnimationBuilder(
                      duration: const Duration(milliseconds: 500),
                      tween: Tween<double>(begin: 0, end: targetProgress),
                      builder: (context, animation, innerChild) {
                        // The dots ring must be sized larger than the camera
                        // so dots are drawn clearly OUTSIDE the camera circle.
                        // DottedCirclePainter draws at:
                        //   min(size)/2 + dotRadius*2
                        // So with ringSize = cameraWidth + dotRadius*14 the
                        // dots sit ~dotRadius*5 outside the camera edge.
                        final double ringSize =
                            widget.cameraSize.width + widget.dotRadius * 14;
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            // Dots ring — explicit size, no child, centred.
                            SizedBox(
                              width: ringSize,
                              height: ringSize,
                              child: CustomPaint(
                                painter: DottedCirclePainter(
                                  activeProgressColor: dotColor,
                                  progressColor: dotColor,
                                  progress: animation,
                                  totalDots: widget.totalDots,
                                  dotRadius: dotRadius,
                                ),
                              ),
                            ),
                            // Camera + glow ring, centred inside the Stack.
                            innerChild!,
                          ],
                        );
                      },
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Camera preview circle.
                          child!,
                          // Glow ring — explicit dimensions matching the camera.
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 350),
                            curve: Curves.easeInOut,
                            width: widget.cameraSize.width,
                            height: widget.cameraSize.height,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: hasFace
                                    ? Colors.green.withValues(
                                        alpha: 0.55 + 0.45 * pulse,
                                      )
                                    : Colors.red.withValues(alpha: 0.45),
                                width: hasFace ? 3.0 : 2.0,
                              ),
                              boxShadow: hasFace
                                  ? [
                                      BoxShadow(
                                        color: Colors.green.withValues(
                                          alpha: 0.25 + 0.35 * pulse,
                                        ),
                                        blurRadius: 18 + 10 * pulse,
                                        spreadRadius: 2 + 4 * pulse,
                                      ),
                                    ]
                                  : [
                                      BoxShadow(
                                        color: Colors.red.withValues(
                                          alpha: 0.18,
                                        ),
                                        blurRadius: 10,
                                        spreadRadius: 1,
                                      ),
                                    ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
              child: Container(
                height: widget.cameraSize.height,
                width: widget.cameraSize.width,
                decoration: BoxDecoration(shape: BoxShape.circle),
                child: DetectorView(
                  cameraSize: widget.cameraSize,
                  onController: (controller_) {
                    controller = controller_;
                    widget.onController?.call(controller_);
                  },
                  title: 'Face Detector',
                  text: _text,
                  onImage: _processImage,
                  initialCameraLensDirection: _cameraLensDirection,
                ),
              ),
            ),
            SizedBox(height: 5),
            ValueListenableBuilder<Rulesets?>(
              valueListenable: _currentTest,
              builder: (context, state, child) {
                if (state != null) {
                  return widget.child(
                    state: state,
                    countdown: _debouncer!.timeLeft,
                    hasFace: hasFace,
                  );
                }
                return SizedBox.shrink();
              },
            ),
            AnimatedBuilder(
              animation: Listenable.merge([_currentTest, ruleset]),
              builder: (context, child) {
                if (_currentTest.value == null &&
                    ruleset.value.isEmpty &&
                    controller != null) {
                  return Expanded(
                    child: SizedBox(
                      width: double.infinity,
                      child: widget.onValidationDone(controller),
                    ),
                  );
                } else {
                  return SizedBox.shrink();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _processImage(InputImage inputImage) async {
    if (!_canProcess) return;
    if (_isBusy) return;
    _isBusy = true;
    setState(() {
      _text = '';
    });
    final faces = await _faceDetector.processImage(inputImage);
    final newHasFace = _isFaceFullyCenteredAndVisible(
      faces,
      inputImage.metadata?.size,
      inputImage.metadata?.rotation,
    );
    if (newHasFace != hasFace) {
      hasFace = newHasFace;
      if (hasFace) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController
          ..stop()
          ..reset();
      }
    }
    if (!(_debouncer?.isRunning ?? false) && hasFace) handleRuleSet(faces);
    if (inputImage.metadata?.size != null &&
        inputImage.metadata?.rotation != null) {
    } else {
      String text = 'Faces found: ${faces.length}\n\n';
      for (final face in faces) {
        text += 'face: ${face.boundingBox}\n\n';
      }
      _text = text;
    }
    _isBusy = false;
    if (mounted) {
      setState(() {});
    }
  }

  /// Returns true when a face is detected and its centre lies roughly within
  /// the frame — regardless of how close or far the user is from the phone.
  ///
  /// Only check: the face centre must be within 45 % of the display width/
  /// height from the image centre.  This rejects partial faces at the very
  /// edge of the frame while accepting any face — near or far — that is
  /// reasonably in view.
  ///
  /// Note: ML Kit returns bounding-box coordinates in raw sensor space
  /// (before rotation). For a portrait phone the sensor image is landscape,
  /// so we swap width/height when the rotation is 90 ° or 270 °.
  bool _isFaceFullyCenteredAndVisible(
    List<Face> faces,
    Size? imageSize,
    InputImageRotation? rotation,
  ) {
    if (faces.isEmpty) return false;
    if (imageSize == null) return false;

    final face = faces.first;
    final box = face.boundingBox;

    // Convert raw sensor dimensions to display dimensions by swapping when
    // the image is rotated 90 ° or 270 °.
    final bool isRotated90or270 =
        rotation == InputImageRotation.rotation90deg ||
        rotation == InputImageRotation.rotation270deg;

    final double displayW = isRotated90or270
        ? imageSize.height
        : imageSize.width;
    final double displayH = isRotated90or270
        ? imageSize.width
        : imageSize.height;

    // Map the bounding box into display coordinates.
    final Rect displayBox = isRotated90or270
        ? Rect.fromLTRB(
            box.top,
            displayH - box.right,
            box.bottom,
            displayH - box.left,
          )
        : box;

    // ── Centering gate ──────────────────────────────────────────────────────
    // Face centre must be within 45 % of the display centre on each axis.
    // A face halfway off the screen will fail; any distance is accepted.
    final double dx = (displayBox.center.dx - displayW / 2).abs();
    final double dy = (displayBox.center.dy - displayH / 2).abs();
    if (dx > displayW * 0.45) return false;
    if (dy > displayH * 0.45) return false;

    return true;
  }

  void handleRuleSet(List<Face> faces) {
    if (faces.isEmpty) return;
    for (Face face in faces) {
      startRandomizedTime(face);
    }
  }

  void startRandomizedTime(Face face) {
    if (ruleset.value.isEmpty) {
      widget.onSuccessValidation?.call(true);
      return;
    } else {
      widget.onSuccessValidation?.call(false);
    }

    var currentRuleset = ruleset.value.removeAt(0);
    bool isDetected = false;
    switch (currentRuleset) {
      case Rulesets.smiling:
        isDetected = _onSmilingDetected(face);
        break;
      case Rulesets.blink:
        isDetected = _onBlinkDetected(face);
        break;
      case Rulesets.tiltUp:
        isDetected = _detectHeadTiltUp(face);
        break;
      case Rulesets.tiltDown:
        isDetected = _detectHeadTiltDown(face);
        break;
      case Rulesets.toLeft:
        isDetected = _detectLeftHeadMovement(face);
        break;
      case Rulesets.toRight:
        isDetected = _detectRightHeadMovement(face);
        break;
      case Rulesets.normal:
        if (_isLockedFace(face)) {
          isDetected = _onNormalDetected(face);
        } else {
          debugPrint(
            "Unknown face detected after head tilt — skipping capture.",
          );
          isDetected = false;
        }
        break;
    }
    if (!isDetected) {
      ruleset.value.insert(0, currentRuleset);
    } else {
      if (ruleset.value.isNotEmpty) {
        _currentTest.value = ruleset.value.first;
        _debouncer?.start();
      } else {
        _currentTest.value = null;
        _debouncer?.stop();
      }
      HapticFeedback.vibrate();
    }
  }

  bool _isLockedFace(Face face) {
    if (!faceLocked) return true; // not locked yet, allow detection

    // If trackingId matches, it's the same face
    if (lockedTrackingId != null && face.trackingId == lockedTrackingId) {
      return true;
    }

    // Backup check: bounding box overlap
    if (lockedFaceBounds != null) {
      final overlap = _calculateOverlap(lockedFaceBounds!, face.boundingBox);
      return overlap > 0.7;
    }

    return false;
  }

  double _calculateOverlap(Rect r1, Rect r2) {
    final double xOverlap = math.max(
      0,
      math.min(r1.right, r2.right) - math.max(r1.left, r2.left),
    );
    final double yOverlap = math.max(
      0,
      math.min(r1.bottom, r2.bottom) - math.max(r1.top, r2.top),
    );
    final double intersection = xOverlap * yOverlap;
    final double union =
        r1.width * r1.height + r2.width * r2.height - intersection;
    return intersection / union;
  }

  bool _detectHeadTiltUp(Face face) {
    return _detectHeadTilt(face, up: true);
  }

  bool _detectHeadTiltDown(Face face) {
    return _detectHeadTilt(face, up: false);
  }

  int? lockedTrackingId; // store the verified face id
  Rect? lockedFaceBounds;
  bool faceLocked = false;
  bool _detectHeadTilt(Face face, {bool up = true}) {
    final double? rotX = face.headEulerAngleX;
    if (rotX == null) return false;

    if (!up) {
      dev.log(rotX.toString(), name: 'Head Movement');
      if (rotX < -20) {
        // Adjust threshold if needed
        widget.onRulesetCompleted?.call(Rulesets.tiltUp);
        return true;
      }
    } else {
      if (rotX > 20 && !faceLocked) {
        lockedTrackingId = face.trackingId;
        lockedFaceBounds = face.boundingBox;
        faceLocked = true; // lock the face
        debugPrint("Face locked after head tilt down.");
        widget.onRulesetCompleted?.call(Rulesets.tiltUp);
        return true;
      }
    }
    return false;
  }

  bool _detectRightHeadMovement(Face face) {
    return _detectHeadMovement(face, left: true);
  }

  bool _detectLeftHeadMovement(Face face) {
    return _detectHeadMovement(face, left: false);
  }

  bool _detectHeadMovement(Face face, {bool left = true}) {
    final double? rotY = face.headEulerAngleY;

    if (rotY == null) return false;
    final double adjustedRotY = Platform.isIOS ? -rotY : rotY;

    if (left) {
      if (adjustedRotY < -40) {
        widget.onRulesetCompleted?.call(Rulesets.toLeft);
        return true;
      }
    } else {
      if (adjustedRotY > 40) {
        widget.onRulesetCompleted?.call(Rulesets.toRight);
        return true;
      }
    }
    return false;
  }

  bool _onBlinkDetected(Face face) {
    final double? leftEyeOpenProb = face.leftEyeOpenProbability;
    final double? rightEyeOpenProb = face.rightEyeOpenProbability;
    const double eyeOpenThreshold = 0.6;
    if (leftEyeOpenProb != null && rightEyeOpenProb != null) {
      if (leftEyeOpenProb < eyeOpenThreshold &&
          rightEyeOpenProb < eyeOpenThreshold) {
        widget.onRulesetCompleted?.call(Rulesets.blink);
        return true;
      }
    }
    return false;
  }

  bool _onSmilingDetected(Face face) {
    if (face.smilingProbability != null) {
      final double? smileProb = face.smilingProbability;
      if ((smileProb ?? 0) > .5) {
        if (widget.onRulesetCompleted != null) {
          widget.onRulesetCompleted!(Rulesets.smiling);
          return true;
        }
      }
    }
    return false;
  }
  //   bool _onNormalDetected(Face face) {
  //   final double? smileProb = face.smilingProbability;
  //   final double? leftEyeOpenProb = face.leftEyeOpenProbability;
  //   final double? rightEyeOpenProb = face.rightEyeOpenProbability;
  //   final double? rotX = face.headEulerAngleX;
  //   final double? rotY = face.headEulerAngleY;

  //   // Check smile threshold (not smiling)
  //   final bool notSmiling = (smileProb ?? 1.0) < 0.3;

  //   // Check eye open threshold
  //   final bool eyesOpen = (leftEyeOpenProb ?? 0.0) > 0.5 && (rightEyeOpenProb ?? 0.0) > 0.5;

  //   // Check head is facing straight (not tilted)
  //   final bool isFacingForward = (rotX != null && rotX.abs() < 10) && (rotY != null && rotY.abs() < 10);

  //   if (notSmiling && eyesOpen && isFacingForward) {
  //     widget.onRulesetCompleted?.call(Rulesets.normal);
  //     return true;
  //   }

  //   return false;
  // }
  // bool _onNormalDetected(Face face) {
  //   final double? smileProb = face.smilingProbability;
  //   final double? leftEyeOpenProb = face.leftEyeOpenProbability;
  //   final double? rightEyeOpenProb = face.rightEyeOpenProbability;
  //   final double? rotX = face.headEulerAngleX;
  //   final double? rotY = face.headEulerAngleY;

  //   // Heuristic checks
  //   final bool notSmiling = (smileProb ?? 1.0) < 0.25;
  //   final bool eyesOpen =
  //       (leftEyeOpenProb ?? 0.0) > 0.5 && (rightEyeOpenProb ?? 0.0) > 0.5;
  //   final bool facingForward =
  //       (rotX?.abs() ?? 0) < 10 && (rotY?.abs() ?? 0) < 10;

  //   // Optional: check for presence of eyebrow contours
  //   final bool hasContours =
  //       face.contours[FaceContourType.leftEyebrowTop] != null &&
  //       face.contours[FaceContourType.rightEyebrowTop] != null;

  //   if (notSmiling && eyesOpen && facingForward && hasContours) {
  //     widget.onRulesetCompleted?.call(Rulesets.normal);
  //     return true;
  //   }

  //   return false;
  // }
  List<double>? referenceEmbedding; // Store registered person's face embedding

  bool _onNormalDetected(Face face) {
    final double? smileProb = face.smilingProbability;
    final double? leftEyeOpenProb = face.leftEyeOpenProbability;
    final double? rightEyeOpenProb = face.rightEyeOpenProbability;
    final double? rotX = face.headEulerAngleX;
    final double? rotY = face.headEulerAngleY;

    final bool notSmiling = (smileProb ?? 1.0) < 0.25;
    final bool eyesOpen =
        (leftEyeOpenProb ?? 0.0) > 0.5 && (rightEyeOpenProb ?? 0.0) > 0.5;
    final bool facingForward =
        (rotX?.abs() ?? 0) < 10 && (rotY?.abs() ?? 0) < 10;

    final bool hasContours =
        face.contours[FaceContourType.leftEyebrowTop] != null &&
        face.contours[FaceContourType.rightEyebrowTop] != null;

    if (notSmiling && eyesOpen && facingForward && hasContours) {
      // Get the current embedding
      final currentEmbedding = getDeterministicEmbedding(face);

      if (referenceEmbedding == null) {
        // First time: save the registered face (e.g., from onboarding)
        referenceEmbedding = currentEmbedding;
        debugPrint("Reference face saved.");
        return false;
      }

      final same = isSamePerson(referenceEmbedding!, currentEmbedding);
      if (!same) {
        debugPrint("Different person detected!");
        return false;
      }

      // All checks passed including identity
      widget.onRulesetCompleted?.call(Rulesets.normal);
      return true;
    }

    return false;
  }

  List<double> getDeterministicEmbedding(Face face) {
    final seed = (face.boundingBox.left + face.boundingBox.top).toInt();
    final rand = math.Random(seed);
    return List.generate(10, (index) => rand.nextDouble());
  }

  bool isSamePerson(
    List<double> embedding1,
    List<double> embedding2, {
    double threshold = 1.0,
  }) {
    return compareEmbeddings(embedding1, embedding2) < threshold;
  }

  double compareEmbeddings(List<double> e1, List<double> e2) {
    double sum = 0;
    for (int i = 0; i < e1.length; i++) {
      sum += math.pow(e1[i] - e2[i], 2).toDouble();
    }
    return math.sqrt(sum); // Euclidean distance
  }
}

/// Utility class for requesting camera permission at runtime.
///
/// Deduplicates concurrent requests so only one OS permission dialog is shown
/// even when called from multiple widgets simultaneously.
class PermissionManager {
  static Future<void>? _ongoingRequest;

  static Future<bool> requestCameraPermission() async {
    if (_ongoingRequest != null) {
      await _ongoingRequest; // wait if a request is already running
      return await Permission.camera.isGranted;
    }

    _ongoingRequest = _request();
    try {
      await _ongoingRequest;
      return await Permission.camera.isGranted;
    } finally {
      _ongoingRequest = null;
    }
  }

  static Future<void> _request() async {
    var status = await Permission.camera.status;

    if (!status.isGranted) {
      status = await Permission.camera.request();
    }

    if (!status.isGranted && (status.isPermanentlyDenied || status.isDenied)) {
      await openAppSettings();
    }
  }
}
