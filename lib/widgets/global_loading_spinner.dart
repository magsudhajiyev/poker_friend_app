import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

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
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _pulseController;
  late Animation<double> _rotationAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _rotationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _rotationAnimation = Tween<double>(
      begin: 0,
      end: 2,
    ).animate(CurvedAnimation(
      parent: _rotationController,
      curve: Curves.linear,
    ));

    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _rotationController.repeat();
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _pulseController.dispose();
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
            AnimatedBuilder(
              animation: _rotationAnimation,
              builder: (context, child) {
                return AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _pulseAnimation.value,
                      child: Transform.rotate(
                        angle: _rotationAnimation.value * 3.14159,
                        child: Container(
                          width: widget.size,
                          height: widget.size,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(widget.size / 2),
                            boxShadow: [
                              BoxShadow(
                                color: Color(0xFF5AC95A).withOpacity(0.3),
                                blurRadius: 20,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(widget.size / 2),
                            child: Image.asset(
                              'logo.png',
                              width: widget.size,
                              height: widget.size,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                // Fallback to a simple poker chip if logo fails to load
                                return Container(
                                  width: widget.size,
                                  height: widget.size,
                                  decoration: BoxDecoration(
                                    color: Color(0xFF5AC95A),
                                    borderRadius: BorderRadius.circular(widget.size / 2),
                                  ),
                                  child: Icon(
                                    Icons.casino,
                                    color: Colors.white,
                                    size: widget.size * 0.5,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 24),
          ] else ...[
            SizedBox(
              width: widget.size * 0.8,
              height: widget.size * 0.8,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF5AC95A)),
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
                color: Color(0xFF9A9A9A),
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