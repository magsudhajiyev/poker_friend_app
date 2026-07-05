import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../design_system/constants/colors.dart';

class GlobalLoadingSpinner extends StatefulWidget {
  final String? message;
  final bool showLogo;
  final double size;

  const GlobalLoadingSpinner({
    Key? key,
    this.message,
    this.showLogo = true,
    this.size = 60.0,
  }) : super(key: key);

  @override
  _GlobalLoadingSpinnerState createState() => _GlobalLoadingSpinnerState();
}

class _GlobalLoadingSpinnerState extends State<GlobalLoadingSpinner>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.showLogo) ...[
            FadeTransition(
              opacity: _fadeAnimation,
              child: Image.asset(
                'assets/logo.png',
                width: widget.size,
                height: widget.size,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 24),
          ] else ...[
            SizedBox(
              width: widget.size * 0.8,
              height: widget.size * 0.8,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.profitGreen),
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (widget.message != null) ...[
            Text(
              widget.message!,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ] else ...[
            Text(
              AppLocalizations.of(context).loadingDefault,
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 14,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Full screen loading overlay
class LoadingOverlay extends StatelessWidget {
  final String? message;
  final bool showLogo;

  const LoadingOverlay({
    Key? key,
    this.message,
    this.showLogo = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Color(0xFF161618).withOpacity(0.95),
      child: Center(
        child: GlobalLoadingSpinner(
          message: message,
          showLogo: showLogo,
        ),
      ),
    );
  }
}

/// Loading state wrapper for screens
class LoadingWrapper extends StatelessWidget {
  final bool isLoading;
  final Widget child;
  final String? loadingMessage;
  final bool showLogo;

  const LoadingWrapper({
    Key? key,
    required this.isLoading,
    required this.child,
    this.loadingMessage,
    this.showLogo = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          LoadingOverlay(
            message: loadingMessage,
            showLogo: showLogo,
          ),
      ],
    );
  }
}
