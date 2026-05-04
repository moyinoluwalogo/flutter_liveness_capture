import 'package:flutter_test/flutter_test.dart';
import 'package:liveness_capture/liveness_capture.dart';

void main() {
  test('Rulesets enum contains all expected values', () {
    const all = Rulesets.values;
    expect(
      all,
      containsAll([
        Rulesets.toLeft,
        Rulesets.toRight,
        Rulesets.blink,
        Rulesets.tiltUp,
        Rulesets.tiltDown,
        Rulesets.smiling,
        Rulesets.normal,
      ]),
    );
  });
}
