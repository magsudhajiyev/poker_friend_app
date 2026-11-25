/// Scale of the seat plate (name + stack) on the hand-logging table: 1.0 at a
/// 390 pt wide screen, within 0.92..1.1 so a 320 pt phone still fits nine
/// seats without overlap and a tablet does not balloon.
double seatPlateScale(double screenWidth) =>
    (screenWidth / 390).clamp(0.92, 1.1).toDouble();
