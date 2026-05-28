import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/colors.dart';

/// Teal rounded button for adding events
/// Full width with "+" prefix and customizable text
class AddEventButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;

  const AddEventButton({
    Key? key,
    this.text = 'Add New Event',
    this.onPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        decoration: BoxDecoration(
          color: AppColors.accentPrimary,
          borderRadius: BorderRadius.circular(1000),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '+',
              style: GoogleFonts.ibmPlexSans(
                fontSize: 17,
                fontWeight: FontWeight.w400,
                color: Colors.black,
                letterSpacing: -0.43,
                height: 1.29,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              text,
              style: GoogleFonts.ibmPlexSans(
                fontSize: 17,
                fontWeight: FontWeight.w400,
                color: Colors.black,
                letterSpacing: -0.43,
                height: 1.29,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
