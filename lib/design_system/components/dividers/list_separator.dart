import 'package:flutter/material.dart';
import '../../constants/colors.dart';

/// Horizontal separator line for lists
/// Matches Figma design with rgba(235,235,245,0.3) color
class ListSeparator extends StatelessWidget {
  final double horizontalPadding;

  const ListSeparator({
    Key? key,
    this.horizontalPadding = 16.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding + 4),
      child: Container(
        height: 1,
        color: AppColors.separatorDark,
      ),
    );
  }
}
