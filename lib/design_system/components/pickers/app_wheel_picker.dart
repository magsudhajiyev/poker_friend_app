import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../constants/colors.dart';
import '../../constants/typography.dart';

/// Scrollable single-column wheel (same look as the onboarding
/// monthly-sessions wheel): magnified centre item between two
/// [AppColors.borderStrong] lines.
///
/// The widget is controlled: [selected] drives the wheel. When [items]
/// changes the wheel is rebuilt on the right item with no jump; when
/// [selected] is not in [items] the wheel shows [fallbackFor] (BTN if
/// present, else the last item) and reports it through [onChanged].
/// [onChanged] fires once the wheel comes to rest, not for every item it
/// passes during a scroll (a fling would otherwise report each item).
/// Height is a fraction of the screen, clamped to [minHeight]..[maxHeight].
class AppWheelPicker<T> extends StatefulWidget {
  final List<T> items;
  final T selected;
  final String Function(T) labelBuilder;
  final ValueChanged<T> onChanged;
  final double? height;
  final double heightFraction;
  final double minHeight;
  final double maxHeight;

  const AppWheelPicker({
    super.key,
    required this.items,
    required this.selected,
    required this.labelBuilder,
    required this.onChanged,
    this.height,
    this.heightFraction = 0.17,
    this.minHeight = 110,
    this.maxHeight = 200,
  });

  /// Default pick when the selected item left the list.
  static T fallbackFor<T>(List<T> items, String Function(T) label) {
    for (final i in items) {
      if (label(i) == 'BTN') return i;
    }
    return items.last;
  }

  @override
  State<AppWheelPicker<T>> createState() => _AppWheelPickerState<T>();
}

class _AppWheelPickerState<T> extends State<AppWheelPicker<T>> {
  static const double _magnification = 1.2;

  late FixedExtentScrollController _ctl;
  bool _syncing = false;

  int get _index {
    final i = widget.items.indexOf(widget.selected);
    if (i >= 0) return i;
    return widget.items
        .indexOf(AppWheelPicker.fallbackFor(widget.items, widget.labelBuilder));
  }

  @override
  void initState() {
    super.initState();
    _ctl = FixedExtentScrollController(initialItem: _index);
    _reportFallback();
  }

  @override
  void didUpdateWidget(AppWheelPicker<T> old) {
    super.didUpdateWidget(old);
    if (!listEquals(old.items, widget.items)) {
      // New item list: swap in a controller already on the right item.
      final stale = _ctl;
      _ctl = FixedExtentScrollController(initialItem: _index);
      WidgetsBinding.instance.addPostFrameCallback((_) => stale.dispose());
    } else if (old.selected != widget.selected) {
      _syncTo(_index);
    }
    _reportFallback();
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  void _syncTo(int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_ctl.hasClients || _ctl.selectedItem == index) return;
      _syncing = true;
      _ctl.jumpToItem(index);
      _syncing = false;
    });
  }

  void _reportFallback() {
    if (widget.items.isEmpty || widget.items.contains(widget.selected)) return;
    final pick = AppWheelPicker.fallbackFor(widget.items, widget.labelBuilder);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onChanged(pick);
    });
  }

  void _onIndex(int i) {
    if (_syncing) return;
    HapticFeedback.selectionClick();
  }

  /// Reports the item the wheel stopped on.
  bool _onScrollEnd(ScrollEndNotification _) {
    if (_syncing || !_ctl.hasClients) return false;
    final i = _ctl.selectedItem.clamp(0, widget.items.length - 1);
    if (i != _index) widget.onChanged(widget.items[i]);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.sizeOf(context).height;
    final h = widget.height ??
        (screenH * widget.heightFraction)
            .clamp(widget.minHeight, widget.maxHeight);
    final extent = h / 3.4;
    return SizedBox(
      height: h,
      child: NotificationListener<ScrollEndNotification>(
        onNotification: _onScrollEnd,
        child: CupertinoPicker(
          key: ObjectKey(_ctl),
          scrollController: _ctl,
          itemExtent: extent,
          magnification: _magnification,
          squeeze: 0.9,
          useMagnifier: true,
          selectionOverlay: Container(
            decoration: const BoxDecoration(
              border: Border.symmetric(
                horizontal: BorderSide(color: AppColors.borderStrong, width: 1),
              ),
            ),
          ),
          onSelectedItemChanged: _onIndex,
          children: [
            for (final item in widget.items)
              Center(
                // Fit the label to 1/magnification of the width: the centre
                // row is magnified, so a label fitted to the full width is cut.
                child: FractionallySizedBox(
                  widthFactor: 1 / _magnification,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      widget.labelBuilder(item),
                      maxLines: 1,
                      style: AppTypography.ibm(
                        fontSize: extent * 0.55,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
