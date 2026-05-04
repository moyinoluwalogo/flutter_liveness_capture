/// The set of liveness challenges that [FaceDetectorScreen] can perform.
///
/// Pass an ordered list of these values to the `ruleset` parameter. The widget
/// will cycle through each challenge in order and require the user to complete
/// it before advancing to the next.
///
/// Example:
/// ```dart
/// ruleset: const [Rulesets.normal, Rulesets.smiling, Rulesets.blink]
/// ```
enum Rulesets {
  /// Ask the user to turn their head to the left.
  toLeft,

  /// Ask the user to turn their head to the right.
  toRight,

  /// Ask the user to blink.
  blink,

  /// Ask the user to tilt their head upward.
  tiltUp,

  /// Ask the user to tilt their head downward.
  tiltDown,

  /// Ask the user to smile.
  smiling,

  /// Ask the user to hold a neutral, forward-facing expression.
  normal,
}
