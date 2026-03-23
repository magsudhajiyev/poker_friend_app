import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../services/subscription_service.dart';

/// Paywall screen for displaying subscription options
class PaywallScreen extends StatefulWidget {
  /// Optional feature name that triggered the paywall
  final String? featureName;

  const PaywallScreen({super.key, this.featureName});

  /// Show the paywall as a modal bottom sheet
  static Future<bool?> show(BuildContext context, {String? featureName}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PaywallScreen(featureName: featureName),
    );
  }

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  bool _isLoading = false;
  bool _isRestoring = false;
  String? _error;
  List<Package> _packages = [];

  @override
  void initState() {
    super.initState();
    _loadOfferings();
  }

  Future<void> _loadOfferings() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await SubscriptionService.fetchOfferings();
      setState(() {
        _packages = SubscriptionService.availablePackages;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load subscription options';
        _isLoading = false;
      });
    }
  }

  Future<void> _purchasePackage(Package package) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final success = await SubscriptionService.purchasePackage(package);

    setState(() {
      _isLoading = false;
    });

    if (success && mounted) {
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Welcome to Premium!'),
          backgroundColor: Color(0xFF5AC95A),
        ),
      );
    }
  }

  Future<void> _restorePurchases() async {
    setState(() {
      _isRestoring = true;
      _error = null;
    });

    final success = await SubscriptionService.restorePurchases();

    setState(() {
      _isRestoring = false;
    });

    if (mounted) {
      if (success) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Purchases restored successfully!'),
            backgroundColor: Color(0xFF5AC95A),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No previous purchases found'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Color(0xFF1A2925),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Container(
                  width: 80,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                SizedBox(height: 24),

                // Premium badge
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star, color: Colors.black, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'PREMIUM',
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 24),

                // Title
                Text(
                  'Unlock Premium Features',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),

                if (widget.featureName != null) ...[
                  SizedBox(height: 8),
                  Text(
                    '${widget.featureName} is a premium feature',
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],

                SizedBox(height: 32),

                // Features list
                _buildFeaturesList(),

                SizedBox(height: 32),

                // Subscription options
                if (_isLoading)
                  Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFBAFF9A)),
                    ),
                  )
                else if (_error != null)
                  _buildErrorState()
                else if (_packages.isEmpty)
                  _buildNoPackagesState()
                else
                  _buildPackagesList(),

                SizedBox(height: 16),

                // Restore purchases button
                TextButton(
                  onPressed: _isRestoring ? null : _restorePurchases,
                  child: _isRestoring
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                          ),
                        )
                      : Text(
                          'Restore Purchases',
                          style: GoogleFonts.ibmPlexSans(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                ),

                SizedBox(height: 8),

                // Terms and privacy
                Text(
                  'Subscriptions auto-renew. Cancel anytime.',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.5),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeaturesList() {
    final features = [
      {'icon': Icons.psychology, 'text': 'AI Hand Analysis with GTO insights'},
      {'icon': Icons.analytics, 'text': 'Advanced session statistics'},
      {'icon': Icons.people, 'text': 'Detailed opponent profiling'},
      {'icon': Icons.cloud_sync, 'text': 'Cloud sync across devices'},
    ];

    return Column(
      children: features.map((feature) {
        return Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Color(0xFFBAFF9A).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  feature['icon'] as IconData,
                  color: Color(0xFFBAFF9A),
                  size: 20,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Text(
                  feature['text'] as String,
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPackagesList() {
    // Sort packages: annual first (best value), then monthly
    final sortedPackages = List<Package>.from(_packages)
      ..sort((a, b) {
        if (a.packageType == PackageType.annual) return -1;
        if (b.packageType == PackageType.annual) return 1;
        return 0;
      });

    return Column(
      children: sortedPackages.map((package) {
        final isAnnual = package.packageType == PackageType.annual;
        return Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: _buildPackageCard(package, isBestValue: isAnnual),
        );
      }).toList(),
    );
  }

  Widget _buildPackageCard(Package package, {bool isBestValue = false}) {
    final price = SubscriptionService.formatPrice(package);
    final period = SubscriptionService.getPeriodDescription(package);

    return GestureDetector(
      onTap: _isLoading ? null : () => _purchasePackage(package),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isBestValue ? Color(0xFFBAFF9A).withOpacity(0.1) : Color(0xFF0D1512),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isBestValue ? Color(0xFFBAFF9A) : Colors.white.withOpacity(0.1),
            width: isBestValue ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        _getPackageTitle(package),
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      if (isBestValue) ...[
                        SizedBox(width: 8),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Color(0xFFBAFF9A),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'BEST VALUE',
                            style: GoogleFonts.ibmPlexSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: 4),
                  Text(
                    '$price $period',
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: isBestValue ? Color(0xFFBAFF9A) : Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Subscribe',
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getPackageTitle(Package package) {
    switch (package.packageType) {
      case PackageType.annual:
        return 'Annual';
      case PackageType.monthly:
        return 'Monthly';
      case PackageType.weekly:
        return 'Weekly';
      case PackageType.lifetime:
        return 'Lifetime';
      default:
        return package.identifier;
    }
  }

  Widget _buildErrorState() {
    return Column(
      children: [
        Icon(Icons.error_outline, color: Colors.red, size: 48),
        SizedBox(height: 16),
        Text(
          _error!,
          style: TextStyle(color: Colors.red),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 16),
        ElevatedButton(
          onPressed: _loadOfferings,
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFFBAFF9A),
            foregroundColor: Colors.black,
          ),
          child: Text('Retry'),
        ),
      ],
    );
  }

  Widget _buildNoPackagesState() {
    // Show demo packages for testing UI
    return _buildDemoPackages();
  }

  Widget _buildDemoPackages() {
    return Column(
      children: [
        // Demo banner
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          margin: EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange.withOpacity(0.5)),
          ),
          child: Text(
            'Demo Mode - Sandbox Testing',
            style: GoogleFonts.ibmPlexSans(
              fontSize: 12,
              color: Colors.orange,
            ),
          ),
        ),

        // Annual package (demo)
        _buildDemoPackageCard(
          title: 'Annual',
          price: '\$39.99',
          period: 'per year',
          isBestValue: true,
          productId: 'premium_annual',
        ),

        SizedBox(height: 12),

        // Monthly package (demo)
        _buildDemoPackageCard(
          title: 'Monthly',
          price: '\$4.99',
          period: 'per month',
          isBestValue: false,
          productId: 'premium_monthly',
        ),
      ],
    );
  }

  Widget _buildDemoPackageCard({
    required String title,
    required String price,
    required String period,
    required bool isBestValue,
    required String productId,
  }) {
    return GestureDetector(
      onTap: () => _handleDemoPurchase(productId, title),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isBestValue ? Color(0xFFBAFF9A).withOpacity(0.1) : Color(0xFF0D1512),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isBestValue ? Color(0xFFBAFF9A) : Colors.white.withOpacity(0.1),
            width: isBestValue ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      if (isBestValue) ...[
                        SizedBox(width: 8),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Color(0xFFBAFF9A),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'BEST VALUE',
                            style: GoogleFonts.ibmPlexSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: 4),
                  Text(
                    '$price $period',
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: isBestValue ? Color(0xFFBAFF9A) : Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Subscribe',
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleDemoPurchase(String productId, String title) async {
    // Show demo purchase dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF1A2925),
        title: Text(
          'Demo Purchase',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'This is a demo purchase for "$title".\n\nIn production, this would connect to the App Store for real payment processing.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFFBAFF9A),
              foregroundColor: Colors.black,
            ),
            child: Text('Simulate Purchase'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      // Simulate successful purchase
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Demo: Premium activated! (Not a real purchase)'),
          backgroundColor: Color(0xFF5AC95A),
        ),
      );
    }
  }
}
