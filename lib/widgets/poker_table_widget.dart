import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';

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

  /// Table width as fraction of available width (default 0.80).
  final double tableWidthFraction;

  /// Table height as fraction of available height (default 0.88).
  final double tableHeightFraction;

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
    this.tableWidthFraction = 0.80,
    this.tableHeightFraction = 0.88,
  }) : super(key: key);

  // ─── SEAT POSITION MATH ─────────────────────────────────────────

  /// Compute the center position for a seat (1-indexed) on the ellipse.
  static Offset getSeatPosition(int seatNumber, Size areaSize,
      {double widthFraction = 0.80, double heightFraction = 0.88}) {
    final double centerX = areaSize.width / 2;
    final double centerY = areaSize.height / 2;
    final double radiusX = (areaSize.width * widthFraction) / 2;
    final double radiusY = (areaSize.height * heightFraction) / 2;

    const double startAngle = math.pi * 1.25;
    final double angleStep = (2 * math.pi) / 9;
    final double angle = startAngle + (angleStep * (seatNumber - 1));

    return Offset(
      centerX + radiusX * math.cos(angle),
      centerY + radiusY * math.sin(angle),
    );
  }

  /// Returns layout variant for a seat's label placement:
  /// - 'top': seat 1 → label below circle
  /// - 'right': seats 6-9 (left side of table) → label to the right
  /// - 'left': seats 2-5 (right side of table) → label to the left
  static String getSeatLayoutVariant(int seatNumber) {
    if (seatNumber == 1) return 'top';
    if ([6, 7, 8, 9].contains(seatNumber)) return 'right';
    return 'left';
  }

  /// Compute the angle for a seat (used for button offset).
  static double getSeatAngle(int seatNumber) {
    const double startAngle = math.pi * 1.25;
    final double angleStep = (2 * math.pi) / 9;
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
                  widthFraction: tableWidthFraction,
                  heightFraction: tableHeightFraction);

              if (seatBuilder != null) {
                // Custom seat builder — caller provides the full widget
                return _buildCustomSeatPositioned(
                    seatNumber, isActive, position);
              } else {
                // Default seat rendering
                return Stack(
                  children: _buildDefaultSeatWidgets(
                      seatNumber, isActive, position),
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

  /// The table felt surface with Figma's green gradient + double border.
  /// Matches Figma node 1015:7173-7174.
  Widget _buildTableSurface(double width, double height) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(224),
        border: Border.all(
          color: const Color(0xFF161A14),
          width: 16.5,
        ),
        gradient: const RadialGradient(
          center: Alignment.center,
          radius: 0.85,
          colors: [
            Color(0xFF224747),
            Color(0xFF123631),
            Color(0xFF02261A),
          ],
          stops: [0.0, 0.5, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
            spreadRadius: 0,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(207.5), // 224 - 16.5
          border: Border.all(
            color: const Color(0xFF12332D),
            width: 5.9,
          ),
        ),
        // Inset shadow overlay: bottom highlight per Figma
        // (0px -1.178px 4.713px #375E6B inset)
        child: ClipRRect(
          borderRadius: BorderRadius.circular(201.6), // 207.5 - 5.9
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Color(0x4D375E6B), // subtle highlight at bottom (30% alpha)
                  Colors.transparent,
                ],
                stops: [0.0, 0.08],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── DEFAULT SEAT RENDERING ─────────────────────────────────────

  Widget _buildDefaultSeatCircle(int seatNumber, bool isActive) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: isActive ? Colors.black : const Color(0xFF2A2A2E),
        shape: BoxShape.circle,
        border: Border.all(
          color: isActive
              ? const Color(0xFF89F1EC)
              : const Color(0xFF89F1EC).withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Center(
        child: Text(
          '$seatNumber',
          style: GoogleFonts.inter(
            color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.4),
            fontWeight: FontWeight.w700,
            fontSize: 17,
            height: 1.45,
          ),
        ),
      ),
    );
  }

  Widget _buildDefaultSeatLabel(int seatNumber, bool isActive, String label) {
    final isDefaultName =
        label.isEmpty || RegExp(r'^Player\s*\d*$').hasMatch(label);
    final displayName = isDefaultName
        ? 'Player'
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

  List<Widget> _buildDefaultSeatWidgets(
      int seatNumber, bool isActive, Offset position) {
    const double circleR = 19.0; // half of 38
    final variant = getSeatLayoutVariant(seatNumber);
    final label = seatLabels[seatNumber] ?? '';

    final circleWidget = Positioned(
      left: position.dx - circleR,
      top: position.dy - circleR,
      child: GestureDetector(
        onTap: onSeatTap != null ? () => onSeatTap!(seatNumber) : null,
        child: _buildDefaultSeatCircle(seatNumber, isActive),
      ),
    );

    Widget labelWidget;
    if (variant == 'top') {
      labelWidget = Positioned(
        left: position.dx - 30,
        top: position.dy + circleR + 4,
        child: SizedBox(
          width: 60,
          child: GestureDetector(
            onTap: onSeatTap != null ? () => onSeatTap!(seatNumber) : null,
            child: Center(
                child: _buildDefaultSeatLabel(seatNumber, isActive, label)),
          ),
        ),
      );
    } else if (variant == 'right') {
      labelWidget = Positioned(
        left: position.dx + circleR + 8,
        top: position.dy - 7,
        child: GestureDetector(
          onTap: onSeatTap != null ? () => onSeatTap!(seatNumber) : null,
          child: _buildDefaultSeatLabel(seatNumber, isActive, label),
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
            child: _buildDefaultSeatLabel(seatNumber, isActive, label),
          ),
        ),
      );
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

    // Offset button 50px toward center
    final buttonOffsetX = -50 * math.cos(seatAngle);
    final buttonOffsetY = -50 * math.sin(seatAngle);

    final buttonImage = Image.asset(
      'icons/button.png',
      width: 32,
      height: 32,
    );

    if (isDealerButtonDraggable && onDealerButtonMoved != null) {
      return Positioned(
        left: position.dx - 16 + buttonOffsetX,
        top: position.dy - 16 + buttonOffsetY,
        // Use Builder to get a context whose ancestor RenderBox
        // covers the full table area for globalToLocal conversion.
        child: Builder(
          builder: (buttonContext) {
            return Draggable<int>(
              data: buttonPosition!,
              feedback: Opacity(
                opacity: 0.7,
                child: Image.asset('icons/button.png', width: 40, height: 40),
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
        left: position.dx - 16 + buttonOffsetX,
        top: position.dy - 16 + buttonOffsetY,
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
