import 'package:flutter/widgets.dart';

/// The layout is drawn for a Galaxy S21+ (384 dp wide at its default display
/// size). Narrower or wider phones scale the fixed sizes by their width.
const double referenceWidth = 384;

/// How much to scale the drawn sizes on a screen [width] dp wide.
double uiScaleFor(double width) => (width / referenceWidth).clamp(0.85, 1.1);

extension ResponsiveContext on BuildContext {
  double get uiScale => uiScaleFor(MediaQuery.sizeOf(this).width);

  /// A size drawn for the reference phone, scaled to this one.
  double s(double value) => value * uiScale;
}
