import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../l10n/app_localizations.dart';

/// Reusable poker table widget that renders a vertical oval table with
/// seats positioned around it. Used across seat setup, dealer table,
/// admin table management, and member table view screens.
///
/// Supports:
/// - Custom seat rendering via [seatBuilder]
/// - Dealer button with optional drag-to-reposition
/// - Center content (e.g. pot display)
/// - Configurable table dimensions
class PokerTableWidget extends StatelessWidget {
  /// Which seats are active/occupied (seat number → active).
  final Map<int, bool> activeSeatMap;

  /// Display labels for each seat (seat number → name).
  final Map<int, String> seatLabels;

  /// Seat number where the dealer button is.
  final int? buttonPosition;

  /// Custom seat widget builder. If null, uses default 38px teal circle.
  /// The builder receives the seat number and whether it's active.
  /// The widget returned should be a self-contained seat (circle + any extras).
  /// It will be centered at the seat's computed position.
  final Widget Function(int seatNumber, bool isActive)? seatBuilder;

  /// Called when a seat is tapped (only used with default seat rendering).
  final void Function(int seatNumber)? onSeatTap;

  /// Whether to show the dealer button chip.
  final bool showDealerButton;

  /// Whether the dealer button can be dragged to another seat.
  final bool isDealerButtonDraggable;

  /// Called when the dealer button is dragged to a new seat.
  final void Function(int newSeat)? onDealerButtonMoved;

  /// Optional widget to display in the center of the table (e.g. pot).
  final Widget? centerContent;

  /// Table width as fraction of available width (default 0.85).
  final double tableWidthFraction;

  /// Table height as fraction of available height (default 0.72).
  final double tableHeightFraction;

  /// Seat ellipse width fraction — defaults to tableWidthFraction.
  /// Set larger than tableWidthFraction to push seats outside the table edge.
  final double? seatWidthFraction;

  /// Seat ellipse height fraction — defaults to tableHeightFraction.
  /// Set larger than tableHeightFraction to push seats outside the table edge.
  final double? seatHeightFraction;

  /// Whether to show the logo text on the table surface.
  /// When false, uses a clean SVG without text.
  final bool showLogo;

  /// Size of the dealer button chip (default 32).
  final double dealerButtonSize;

  /// Rotation in quarter turns to apply to the dealer button image.
  /// Use to counter-rotate when the whole widget is rotated.
  final int dealerButtonQuarterTurns;

  /// Optional per-seat nudge for the dealer button position (in widget coords).
  /// Called with the seat number the button is on. Return Offset.zero for no nudge.
  final Offset Function(int seatNumber)? dealerButtonNudge;

  const PokerTableWidget({
    Key? key,
    required this.activeSeatMap,
    this.seatLabels = const {},
    this.buttonPosition,
    this.seatBuilder,
    this.onSeatTap,
    this.showDealerButton = true,
    this.isDealerButtonDraggable = false,
    this.onDealerButtonMoved,
    this.centerContent,
    this.tableWidthFraction = 0.85,
    this.tableHeightFraction = 0.72,
    this.seatWidthFraction,
    this.seatHeightFraction,
    this.showLogo = true,
    this.dealerButtonSize = 32,
    this.dealerButtonQuarterTurns = 0,
    this.dealerButtonNudge,
  }) : super(key: key);

  // ─── SEAT POSITION MATH ─────────────────────────────────────────

  /// Compute the center position for a seat (1-indexed) on the ellipse.
  static Offset getSeatPosition(int seatNumber, Size areaSize,
      {double widthFraction = 0.80, double heightFraction = 0.88}) {
    final double centerX = areaSize.width / 2;
    final double centerY = areaSize.height / 2;
    final double radiusX = (areaSize.width * widthFraction) / 2;
    final double radiusY = (areaSize.height * heightFraction) / 2;

    final double angleStep = (2 * math.pi) / 9;
    // +π/12 (15°) rotates the layout so the gap between seats 7 and 8
    // falls at 180° (left-center), aligning with the notch in Table.svg.
    const double startAngle = math.pi * 1.25 + (2 * math.pi) / 9 + math.pi / 12;
    final double angle = startAngle + (angleStep * (seatNumber - 1));

    return Offset(
      centerX + radiusX * math.cos(angle),
      centerY + radiusY * math.sin(angle),
    );
  }

  /// Returns layout variant for a seat's label placement:
  /// - 'top': seats 9,1 (top of table) → label below circle
  /// - 'right': seats 7,8 (left side of table) → label to the right
  /// - 'left': seats 2,3,4 (right side of table) → label to the left
  static String getSeatLayoutVariant(int seatNumber) {
    if (seatNumber == 9 || seatNumber == 1) return 'top';
    if ([5, 6, 7, 8].contains(seatNumber)) return 'right';
    return 'left'; // 2, 3, 4
  }

  /// Compute the angle for a seat (used for button offset).
  static double getSeatAngle(int seatNumber) {
    final double angleStep = (2 * math.pi) / 9;
    const double startAngle = math.pi * 1.25 + (2 * math.pi) / 9 + math.pi / 12;
    return startAngle + (angleStep * (seatNumber - 1));
  }

  // ─── BUILD ──────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final areaSize = Size(constraints.maxWidth, constraints.maxHeight);
        final tableWidth = constraints.maxWidth * tableWidthFraction;
        final tableHeight = constraints.maxHeight * tableHeightFraction;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            // Table surface
            Center(
              child: _buildTableSurface(tableWidth, tableHeight),
            ),

            // Seats
            ...List.generate(9, (index) {
              final seatNumber = index + 1;
              final isActive = activeSeatMap[seatNumber] ?? false;
              final position = getSeatPosition(seatNumber, areaSize,
                  widthFraction: seatWidthFraction ?? tableWidthFraction,
                  heightFraction: seatHeightFraction ?? tableHeightFraction);

              if (seatBuilder != null) {
                // Custom seat builder — caller provides the full widget
                return _buildCustomSeatPositioned(
                    seatNumber, isActive, position);
              } else {
                // Default seat rendering
                return Stack(
                  children: _buildDefaultSeatWidgets(
                      context, seatNumber, isActive, position),
                );
              }
            }),

            // Dealer button
            if (showDealerButton && buttonPosition != null)
              _buildDealerButton(areaSize, constraints),

            // Center content
            if (centerContent != null)
              Center(child: centerContent!),
          ],
        );
      },
    );
  }

  Widget _buildTableSurface(double width, double height) {
    return SvgPicture.asset(
      showLogo ? 'assets/icons/Table.svg' : 'assets/icons/Table_clean.svg',
      width: width,
      height: height,
      fit: BoxFit.fill,
    );
  }

  // ─── DEFAULT SEAT RENDERING ─────────────────────────────────────

  Widget _buildDefaultSeatCircle(int seatNumber, bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF161719),
        borderRadius: BorderRadius.circular(35),
        border: Border.all(
          color: isActive
              ? const Color(0xFFA3FF78)
              : const Color(0xFF2C2C2E),
          width: 2,
        ),
      ),
      child: Text(
        '$seatNumber',
        style: GoogleFonts.ibmPlexMono(
          color: const Color(0xFFA3FF78),
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildDefaultSeatLabel(BuildContext context, int seatNumber, bool isActive, String label) {
    final l10n = AppLocalizations.of(context);
    final isDefaultName =
        label.isEmpty || RegExp(r'^Player\s*\d*$').hasMatch(label);
    final displayName = isDefaultName
        ? l10n.pokerTablePlayerFallback
        : (label.length > 8 ? '${label.substring(0, 8)}...' : label);

    return Text(
      displayName,
      style: GoogleFonts.ibmPlexSans(
        color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.4),
        fontSize: 10,
        fontWeight: FontWeight.w500,
        height: 1.44,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildSeatNameBadge(String name) {
    const badgeWidth = 52.0;
    const badgeHeight = 17.0;
    const tailHeight = 3.5;
    final truncated = name.length > 8 ? '${name.substring(0, 6)}..' : name;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          width: badgeWidth,
          height: badgeHeight,
          decoration: BoxDecoration(
            color: const Color(0xFF0097D2),
            borderRadius: BorderRadius.circular(8.5),
          ),
          child: Center(
            child: Text(
              truncated,
              style: GoogleFonts.ibmPlexSans(
                fontSize: 10.0,
                fontWeight: FontWeight.w500,
                color: Colors.white,
                height: 1.24,
              ),
              maxLines: 1,
            ),
          ),
        ),
        CustomPaint(
          size: const Size(badgeWidth, tailHeight),
          painter: _SeatBadgeTailPainter(),
        ),
      ],
    );
  }

  List<Widget> _buildDefaultSeatWidgets(
      BuildContext context, int seatNumber, bool isActive, Offset position) {
    const double circleR = 15.5; // half of ~31px pill height
    const double badgeW = 52.0;
    const double badgeH = 20.5;
    final variant = getSeatLayoutVariant(seatNumber);
    final label = seatLabels[seatNumber] ?? '';
    final isDefaultName = label.isEmpty || RegExp(r'^Player\s*\d*$').hasMatch(label);
    final showBadge = isActive && !isDefaultName;

    final circleWidget = Positioned(
      left: position.dx - circleR,
      top: position.dy - circleR,
      child: GestureDetector(
        onTap: onSeatTap != null ? () => onSeatTap!(seatNumber) : null,
        child: _buildDefaultSeatCircle(seatNumber, isActive),
      ),
    );

    Widget labelWidget;

    if (showBadge) {
      final badge = _buildSeatNameBadge(label);
      if (variant == 'top') {
        labelWidget = Positioned(
          left: position.dx - badgeW / 2,
          top: position.dy + circleR + 4,
          child: GestureDetector(
            onTap: onSeatTap != null ? () => onSeatTap!(seatNumber) : null,
            child: badge,
          ),
        );
      } else if (variant == 'right') {
        labelWidget = Positioned(
          left: position.dx + circleR + 4,
          top: position.dy - badgeH / 2,
          child: GestureDetector(
            onTap: onSeatTap != null ? () => onSeatTap!(seatNumber) : null,
            child: badge,
          ),
        );
      } else {
        // 'left' — badge sits to the left of the seat circle
        labelWidget = Positioned(
          left: position.dx - circleR - 4,
          top: position.dy - badgeH / 2,
          child: GestureDetector(
            onTap: onSeatTap != null ? () => onSeatTap!(seatNumber) : null,
            child: FractionalTranslation(
              translation: const Offset(-1.0, 0.0),
              child: badge,
            ),
          ),
        );
      }
    } else {
      if (variant == 'top') {
        labelWidget = Positioned(
          left: position.dx - 30,
          top: position.dy + circleR + 4,
          child: SizedBox(
            width: 60,
            child: GestureDetector(
              onTap: onSeatTap != null ? () => onSeatTap!(seatNumber) : null,
              child: Center(
                  child: _buildDefaultSeatLabel(context, seatNumber, isActive, label)),
            ),
          ),
        );
      } else if (variant == 'right') {
        labelWidget = Positioned(
          left: position.dx + circleR + 8,
          top: position.dy - 7,
          child: GestureDetector(
            onTap: onSeatTap != null ? () => onSeatTap!(seatNumber) : null,
            child: _buildDefaultSeatLabel(context, seatNumber, isActive, label),
          ),
        );
      } else {
        labelWidget = Positioned(
          left: position.dx - circleR - 8,
          top: position.dy - 7,
          child: GestureDetector(
            onTap: onSeatTap != null ? () => onSeatTap!(seatNumber) : null,
            child: FractionalTranslation(
              translation: const Offset(-1.0, 0.0),
              child: _buildDefaultSeatLabel(context, seatNumber, isActive, label),
            ),
          ),
        );
      }
    }

    return [circleWidget, labelWidget];
  }

  // ─── CUSTOM SEAT RENDERING ──────────────────────────────────────

  Widget _buildCustomSeatPositioned(
      int seatNumber, bool isActive, Offset position) {
    final seatWidget = seatBuilder!(seatNumber, isActive);

    // For custom seats, we center the widget at the computed position
    // by wrapping in a FractionalTranslation
    return Positioned(
      left: position.dx,
      top: position.dy,
      child: FractionalTranslation(
        translation: const Offset(-0.5, -0.5),
        child: seatWidget,
      ),
    );
  }

  // ─── DEALER BUTTON ──────────────────────────────────────────────

  Widget _buildDealerButton(Size areaSize, BoxConstraints constraints) {
    final position = getSeatPosition(buttonPosition!, areaSize,
        widthFraction: tableWidthFraction,
        heightFraction: tableHeightFraction);
    final seatAngle = getSeatAngle(buttonPosition!);

    // Offset button toward center
    final buttonOffset = dealerButtonSize * 1.5;
    final nudge = dealerButtonNudge?.call(buttonPosition!) ?? Offset.zero;
    final buttonOffsetX = -buttonOffset * math.cos(seatAngle) + nudge.dx;
    final buttonOffsetY = -buttonOffset * math.sin(seatAngle) + nudge.dy;
    final half = dealerButtonSize / 2;

    Widget makeButtonImage(double size) {
      final svg = SvgPicture.asset(
        'assets/icons/Dealer Button.svg',
        width: size,
        height: size,
      );
      return dealerButtonQuarterTurns != 0
          ? RotatedBox(quarterTurns: dealerButtonQuarterTurns, child: svg)
          : svg;
    }

    final buttonImage = makeButtonImage(dealerButtonSize);

    if (isDealerButtonDraggable && onDealerButtonMoved != null) {
      return Positioned(
        left: position.dx - half + buttonOffsetX,
        top: position.dy - half + buttonOffsetY,
        // Use Builder to get a context whose ancestor RenderBox
        // covers the full table area for globalToLocal conversion.
        child: Builder(
          builder: (buttonContext) {
            return Draggable<int>(
              data: buttonPosition!,
              feedback: Opacity(
                opacity: 0.7,
                child: makeButtonImage(dealerButtonSize * 1.25),
              ),
              childWhenDragging: Opacity(
                opacity: 0.3,
                child: buttonImage,
              ),
              onDragEnd: (details) {
                _handleDealerButtonDrop(
                    details, buttonContext, areaSize);
              },
              child: buttonImage,
            );
          },
        ),
      );
    } else {
      return Positioned(
        left: position.dx - half + buttonOffsetX,
        top: position.dy - half + buttonOffsetY,
        child: Opacity(
          opacity: isDealerButtonDraggable ? 1.0 : 0.6,
          child: buttonImage,
        ),
      );
    }
  }

  void _handleDealerButtonDrop(
      DraggableDetails details, BuildContext context, Size areaSize) {
    // Walk up to find the RenderBox of the Stack (table area)
    final RenderBox? renderBox =
        context.findAncestorRenderObjectOfType<RenderStack>() as RenderBox?;
    if (renderBox == null) return;

    // With pointerDragAnchorStrategy, details.offset is the pointer position
    // (which is where the user wants to drop the button).
    final localPosition = renderBox.globalToLocal(details.offset);

    int? closestSeat;
    double minDistance = double.infinity;

    for (int i = 1; i <= 9; i++) {
      if (activeSeatMap[i] == true) {
        final seatPos = getSeatPosition(i, areaSize,
            widthFraction: tableWidthFraction,
            heightFraction: tableHeightFraction);
        final distance = (seatPos - localPosition).distance;

        if (distance < minDistance) {
          minDistance = distance;
          closestSeat = i;
        }
      }
    }

    if (closestSeat != null && minDistance < 150) {
      onDealerButtonMoved!(closestSeat);
    }
  }
}

class _SeatBadgeTailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF0097D2);
    final path = Path()
      ..moveTo(size.width * 0.715, 0)
      ..lineTo(size.width * 0.865, 0)
      ..lineTo(size.width * 0.865, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_SeatBadgeTailPainter oldDelegate) => false;
}
