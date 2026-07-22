import 'package:flutter/material.dart';

/// Baseline phone size — UI scales uniformly from this reference.
class ResponsiveLayout {
  ResponsiveLayout._(this._context);

  final BuildContext _context;

  static const double designWidth = 390;
  static const double designHeight = 844;
  static const double compactWidth = 360;
  static const double narrowWidth = 340;

  static ResponsiveLayout of(BuildContext context) =>
      ResponsiveLayout._(context);

  Size get size => MediaQuery.sizeOf(_context);
  EdgeInsets get padding => MediaQuery.paddingOf(_context);

  /// Uniform scale — clamped so UI stays readable on all phones.
  double get scale {
    final widthScale = size.width / designWidth;
    final heightScale = size.height / designHeight;
    return (widthScale < heightScale ? widthScale : heightScale)
        .clamp(0.82, 1.12);
  }

  double sp(double value) => value * scale;
  double w(double value) => value * scale;
  double h(double value) => value * scale;

  bool get isCompact => size.width < compactWidth;
  bool get isNarrow => size.width < narrowWidth;

  /// Bottom offsets for in-game controls (proportional to screen height).
  double get gameControlBottom => size.height * 0.033;
  double get linkButtonBottom => size.height * 0.118;

  /// Design width for chat (2) + abilities (4) + gaps + side pads at scale 1.
  static const double bottomBarDesignWidth =
      12 + 48 + 8 + 48 + 16 + 58 + 8 + 58 + 8 + 58 + 8 + 72 + 12;

  /// Extra shrink so 6 bottom controls never collide on narrow phones.
  double get bottomControlFit {
    final needed = w(bottomBarDesignWidth);
    final usable = size.width - padding.left - padding.right;
    if (needed <= usable) return 1.0;
    return (usable / needed).clamp(0.55, 1.0);
  }

  double get bottomCommsSize => w(48) * bottomControlFit;
  double get bottomAbilitySize => w(58) * bottomControlFit;
  double get bottomBoostSize => w(72) * bottomControlFit;
  double get bottomControlGap => w(8) * bottomControlFit;
  double get bottomBarSidePad => w(12) * bottomControlFit;
}

extension ResponsiveLayoutContext on BuildContext {
  ResponsiveLayout get responsive => ResponsiveLayout.of(this);
}

/// Reports child size changes — used for dynamic HUD height.
class MeasureSize extends StatefulWidget {
  const MeasureSize({
    super.key,
    required this.onChange,
    required this.child,
  });

  final ValueChanged<Size> onChange;
  final Widget child;

  @override
  State<MeasureSize> createState() => _MeasureSizeState();
}

class _MeasureSizeState extends State<MeasureSize> {
  Size? _lastSize;

  void _report() {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final size = box.size;
    if (_lastSize == size) return;
    _lastSize = size;
    widget.onChange(size);
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _report());
    return NotificationListener<SizeChangedLayoutNotification>(
      onNotification: (_) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _report());
        return false;
      },
      child: SizeChangedLayoutNotifier(child: widget.child),
    );
  }
}

/// Clamps system text scaling so layouts stay consistent across devices.
Widget responsiveAppBuilder(BuildContext context, Widget? child) {
  final mq = MediaQuery.of(context);
  final rawScale = mq.textScaler.scale(1);
  final clamped = rawScale.clamp(0.9, 1.05);
  return MediaQuery(
    data: mq.copyWith(textScaler: TextScaler.linear(clamped)),
    child: child ?? const SizedBox.shrink(),
  );
}
