import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/club.dart';
import '../services/auth_service.dart';
import '../services/club_service.dart';
import '../services/session_result_service.dart';
import '../screens/statistics_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/intro_screen.dart';
import '../screens/club/club_dashboard_screen.dart';
import '../screens/paywall_screen.dart';
import '../screens/earnings_chart_screen.dart';
import 'register_club_dialog.dart';

/// Profile screen drawer matching Figma design (node 522-4548)
class AppNavigationDrawer extends StatefulWidget {
  final String? username;
  final String? email;

  const AppNavigationDrawer({
    super.key,
    this.username,
    this.email,
  });

  @override
  State<AppNavigationDrawer> createState() => _AppNavigationDrawerState();
}

class _AppNavigationDrawerState extends State<AppNavigationDrawer> {
  List<Club> _clubs = [];
  Map<String, int> _clubMemberCounts = {};
  Map<String, String> _clubUserRoles = {};
  bool _hasLoadedClubs = false;
  bool _isClubsExpanded = false;

  // Avatar colors matching Figma examples
  static const List<Color> _avatarColors = [
    Color(0xFF7C3AED), // purple
    Color(0xFFD97706), // amber
    Color(0xFF06966A), // green
    Color(0xFFDC2626), // red
    Color(0xFF2563EB), // blue
    Color(0xFFDB2777), // pink
    Color(0xFF0891B2), // cyan
    Color(0xFFCA8A04), // yellow
  ];

  @override
  void initState() {
    super.initState();
    _loadClubs();
  }

  Future<void> _loadClubs() async {
    if (_hasLoadedClubs) return;

    try {
      final clubs = await ClubService.getClubs();
      if (mounted) {
        setState(() {
          _clubs = clubs;
          _hasLoadedClubs = true;
        });
      }
      // Load member counts and roles in background
      _loadClubDetails(clubs);
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasLoadedClubs = true;
        });
      }
    }
  }

  Future<void> _loadClubDetails(List<Club> clubs) async {
    final userId = AuthService.userId;
    if (userId == null) return;

    for (final club in clubs) {
      try {
        final count = await ClubService.getMemberCount(club.id);
        final role = await ClubService.getMemberRole(club.id, userId);
        if (mounted) {
          setState(() {
            _clubMemberCounts[club.id] = count;
            if (role != null) {
              _clubUserRoles[club.id] = role.name;
            }
          });
        }
      } catch (_) {}
    }
  }

  String _getClubInitials(String name) {
    final trimmed = name.trim();
    if (trimmed.length < 2) return trimmed.toUpperCase();
    return trimmed.substring(0, 2).toUpperCase();
  }

  Color _getAvatarColor(int index) {
    return _avatarColors[index % _avatarColors.length];
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final screenWidth = MediaQuery.of(context).size.width;

    return Drawer(
      backgroundColor: Colors.transparent,
      width: screenWidth, // Full screen width
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0B0A0A),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Calculate ellipse size for glow effect
            final ellipseWidth = constraints.maxWidth * 1.5;
            final ellipseHeight = constraints.maxHeight * 0.6;

            return Stack(
              children: [
                // Elliptical teal glow at top (same as home screen)
                Positioned(
                  top: -constraints.maxHeight * 0.15,
                  right: -constraints.maxWidth * 0.25,
                  child: Transform.scale(
                    scaleX: 1.0,
                    scaleY: 0.7,
                    child: Container(
                      width: ellipseWidth,
                      height: ellipseHeight,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          center: Alignment.center,
                          radius: 0.5,
                          colors: [
                            const Color(0xFF1A4A4A).withOpacity(0.6),
                            const Color(0xFF133538).withOpacity(0.4),
                            const Color(0xFF133538).withOpacity(0.2),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.3, 0.6, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),

                // Main content
                Padding(
                  padding: EdgeInsets.only(top: topPadding),
                  child: Column(
                    children: [
                      // Header row: Close button + Upgrade button
                      _buildHeaderRow(context),

                      const SizedBox(height: 32),

                      // Profile section (avatar, name, email)
                      _buildProfileSection(),

                      const SizedBox(height: 32),

                      // Menu cards
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            children: [
                              // Menu Card 1: Statistics, Clubs (expandable), Bankroll
                              _buildMenuCard1(),

                              const SizedBox(height: 16),

                              // Menu Card 2: Settings, Register Club, Help, Logout
                              _buildMenuCard([
                                _MenuItemData(
                                  iconPath: 'icons/figma_icons/gear.svg',
                                  fallbackIcon: Icons.settings_rounded,
                                  label: 'Settings',
                                  onTap: () {
                                    Navigator.pop(context);
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => SettingsScreen(),
                                      ),
                                    );
                                  },
                                ),
                                _MenuItemData(
                                  iconPath: 'icons/figma_icons/plus.svg',
                                  fallbackIcon: Icons.add_circle_outline_rounded,
                                  label: 'Register Club',
                                  onTap: () {
                                    Navigator.pop(context);
                                    showRegisterClubDialog(context);
                                  },
                                ),
                                _MenuItemData(
                                  iconPath: 'icons/figma_icons/question.svg',
                                  fallbackIcon: Icons.help_outline_rounded,
                                  label: 'Help & Support',
                                  onTap: () {
                                    Navigator.pop(context);
                                    _showHelpDialog(context);
                                  },
                                ),
                                _MenuItemData(
                                  iconPath: 'icons/figma_icons/sign_out.svg',
                                  fallbackIcon: Icons.logout_rounded,
                                  label: 'Log out',
                                  isDestructive: true,
                                  onTap: () {
                                    Navigator.pop(context);
                                    _showSignOutConfirmation(context);
                                  },
                                ),
                              ]),

                              const SizedBox(height: 32),
                            ],
                          ),
                        ),
                      ),

                      // Footer
                      _buildFooter(),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeaderRow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Close button (X) - just the icon, no background
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const SizedBox(
              width: 44,
              height: 44,
              child: Center(
                child: Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),

          // Upgrade button with diamond icon and glow
          GestureDetector(
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PaywallScreen()),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF104034).withOpacity(0.6),
                borderRadius: BorderRadius.circular(70),
                border: Border.all(
                  color: const Color(0xFF89F1EC),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF91FFFB).withOpacity(0.25),
                    blurRadius: 21,
                    offset: const Offset(3, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Diamond icon
                  const Icon(
                    Icons.diamond_outlined,
                    color: Color(0xFF89F1EC),
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Upgrade',
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF89F1EC),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileSection() {
    return Column(
      children: [
        // Avatar — Google photo or initials fallback
        _buildAvatar(56),

        const SizedBox(height: 16),

        // Name (24px, SemiBold)
        Text(
          widget.username ?? 'User',
          style: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),

        const SizedBox(height: 4),

        // Email (15px, 70% white)
        if (widget.email != null)
          Text(
            widget.email!,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: Colors.white.withOpacity(0.7),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );
  }

  Widget _buildMenuCard(List<_MenuItemData> items) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF131616),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        children: items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final isLast = index == items.length - 1;

          return Column(
            children: [
              _buildMenuItem(item),
              if (!isLast) const SizedBox(height: 24),
            ],
          );
        }).toList(),
      ),
    );
  }

  /// Menu Card 1 with expandable Clubs section
  Widget _buildMenuCard1() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF131616),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        children: [
          // Statistics
          _buildMenuItem(_MenuItemData(
            iconPath: 'icons/figma_icons/stats.svg',
            fallbackIcon: Icons.bar_chart_rounded,
            label: 'Statistics',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => StatisticsScreen()),
              );
            },
          )),
          const SizedBox(height: 24),

          // Clubs (expandable)
          _buildExpandableClubsItem(),

          const SizedBox(height: 24),

          // Bankroll
          _buildMenuItem(_MenuItemData(
            iconPath: 'icons/figma_icons/bankroll.svg',
            fallbackIcon: Icons.account_balance_wallet_rounded,
            label: 'Bankroll',
            onTap: () => _navigateToBankroll(context),
          )),
        ],
      ),
    );
  }

  Widget _buildExpandableClubsItem() {
    final color = Colors.white.withOpacity(0.9);

    return Column(
      children: [
        // Clubs header row (tappable to expand/collapse)
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              setState(() {
                _isClubsExpanded = !_isClubsExpanded;
              });
            },
            borderRadius: BorderRadius.circular(8),
            splashColor: Colors.white.withOpacity(0.1),
            highlightColor: Colors.white.withOpacity(0.05),
            child: SizedBox(
              height: 40,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    // Icon
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: _buildIcon('icons/figma_icons/clubs.svg', 24, color),
                    ),
                    const SizedBox(width: 6),
                    // Label
                    Expanded(
                      child: Text(
                        'Clubs',
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 17,
                          fontWeight: FontWeight.w400,
                          color: color,
                          height: 18 / 17, // line-height 18px
                        ),
                      ),
                    ),
                    // Chevron (rotates when expanded)
                    AnimatedRotation(
                      turns: _isClubsExpanded ? 0.0 : -0.25,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.keyboard_arrow_down,
                        color: Colors.white.withOpacity(0.5),
                        size: 24,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Expandable clubs list
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: _buildClubsList(),
          crossFadeState: _isClubsExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
      ],
    );
  }

  Widget _buildClubsList() {
    if (_clubs.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(left: 22, top: 12),
        child: Text(
          'No clubs yet',
          style: GoogleFonts.ibmPlexSans(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: Colors.white.withOpacity(0.5),
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        children: _clubs.asMap().entries.map((entry) {
          return _buildClubItem(entry.value, entry.key);
        }).toList(),
      ),
    );
  }

  Widget _buildClubItem(Club club, int index) {
    final memberCount = _clubMemberCounts[club.id];
    final userRole = _clubUserRoles[club.id];
    final initials = _getClubInitials(club.name);
    final avatarColor = _getAvatarColor(index);

    // Build subtitle
    String subtitle = memberCount != null ? '$memberCount members' : '';

    // Role badge
    final isAdmin = userRole == 'owner' || userRole == 'admin';
    final roleLabel = userRole == 'owner'
        ? 'Admin'
        : userRole == 'admin'
            ? 'Admin'
            : userRole == 'dealer'
                ? 'Dealer'
                : 'Member';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ClubDashboardScreen(club: club),
            ),
          );
        },
        borderRadius: BorderRadius.circular(8),
        splashColor: Colors.white.withOpacity(0.1),
        highlightColor: Colors.white.withOpacity(0.05),
        child: Padding(
          padding: const EdgeInsets.only(left: 22, top: 8, bottom: 8),
          child: SizedBox(
            height: 54,
            child: Row(
              children: [
                // Avatar (36px, rounded 10px)
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: avatarColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      initials,
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Name + subtitle
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        club.name,
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: GoogleFonts.ibmPlexSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                            color: const Color(0xFF808285),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                // Role badge
                if (userRole != null)
                  Container(
                    width: 56,
                    height: 20,
                    decoration: BoxDecoration(
                      color: isAdmin
                          ? const Color(0xFF1B4341)
                          : const Color(0xFF1B1E24),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Text(
                        roleLabel,
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isAdmin
                              ? const Color(0xFF89F1EC)
                              : const Color(0xFF67696D),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(width: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIcon(String path, double size, Color color) {
    if (path.endsWith('.svg')) {
      return SvgPicture.asset(
        path,
        width: size,
        height: size,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      );
    } else {
      return Image.asset(
        path,
        width: size,
        height: size,
        color: color,
      );
    }
  }

  Widget _buildMenuItem(_MenuItemData item) {
    final color = item.isDestructive
        ? const Color(0xFFFF6B6B)
        : Colors.white.withOpacity(0.9);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(8),
        splashColor: Colors.white.withOpacity(0.1),
        highlightColor: Colors.white.withOpacity(0.05),
        child: SizedBox(
          height: 40,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                // Icon
                SizedBox(
                  width: 24,
                  height: 24,
                  child: item.iconPath != null
                      ? _buildIcon(item.iconPath!, 24, color)
                      : Icon(
                          item.fallbackIcon,
                          color: color,
                          size: 24,
                        ),
                ),
                const SizedBox(width: 6),
                // Label
                Text(
                  item.label,
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 17,
                    fontWeight: FontWeight.w400,
                    color: color,
                    height: 18 / 17, // line-height 18px
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        children: [
          // Version
          Text(
            'Version 1.0.0',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: Colors.white.withOpacity(0.4),
            ),
          ),
          const SizedBox(height: 4),
          // App name
          Text(
            'Final Table',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.white.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 4),
          // Last login
          Text(
            'Last login: Today',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w400,
              color: Colors.white.withOpacity(0.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(double size) {
    final photoURL = AuthService.userPhotoURL;
    if (photoURL != null && photoURL.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: CachedNetworkImage(
          imageUrl: photoURL,
          width: size,
          height: size,
          fit: BoxFit.cover,
          placeholder: (context, url) => _buildInitialsAvatar(size),
          errorWidget: (context, url, error) => _buildInitialsAvatar(size),
        ),
      );
    }
    return _buildInitialsAvatar(size);
  }

  Widget _buildInitialsAvatar(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2A5A30), Color(0xFF1A3A20)],
        ),
        borderRadius: BorderRadius.circular(size / 2),
      ),
      child: Center(
        child: Text(
          _getInitials(),
          style: GoogleFonts.inter(
            fontSize: size * 0.357,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF87ED81),
          ),
        ),
      ),
    );
  }

  String _getInitials() {
    if (widget.username == null || widget.username!.isEmpty) return 'U';
    final parts = widget.username!.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return widget.username![0].toUpperCase();
  }

  Future<void> _navigateToBankroll(BuildContext context) async {
    Navigator.pop(context); // Close drawer first

    // Check if there are any session results
    try {
      final results = await SessionResultService.getAllSessionResults();
      if (results.isEmpty) {
        if (context.mounted) {
          _showNoEarningsDataDialog(context);
        }
      } else {
        if (context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const EarningsChartScreen(),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        _showNoEarningsDataDialog(context);
      }
    }
  }

  void _showNoEarningsDataDialog(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeOut,
          )),
          child: child,
        );
      },
      pageBuilder: (context, animation, secondaryAnimation) {
        return Stack(
          children: [
            // Blurred backdrop
            Positioned.fill(
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                  child: Container(
                    color: Colors.black.withOpacity(0.0),
                  ),
                ),
              ),
            ),

            // Dialog content
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Main dialog container
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF131613),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      padding: const EdgeInsets.only(top: 24),
                      child: Column(
                        children: [
                          // Icon
                          const Icon(
                            Icons.show_chart_rounded,
                            color: Color(0xFF89F1EC),
                            size: 48,
                          ),

                          const SizedBox(height: 16),

                          // Title section
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Text(
                              'No Earnings Data Yet',
                              style: GoogleFonts.ibmPlexSans(
                                fontSize: 16,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0,
                                height: 1.2,
                                decoration: TextDecoration.none,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Description section
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Text(
                              'Add some session results first to view your earnings chart. You can add results from the Profile page.',
                              style: GoogleFonts.ibmPlexSans(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.6),
                                fontWeight: FontWeight.w400,
                                letterSpacing: 0.24,
                                height: 1.5,
                                decoration: TextDecoration.none,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Divider
                          Container(
                            height: 1,
                            color: Colors.white.withOpacity(0.1),
                          ),

                          // OK button
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
                              child: Text(
                                'OK',
                                style: GoogleFonts.ibmPlexSans(
                                  fontSize: 16,
                                  color: const Color(0xFF89F1EC),
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0,
                                  height: 1.2,
                                  decoration: TextDecoration.none,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16), // Bottom safe area padding
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'Help & Support',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Need help with Final Table?',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Contact us at:\nsupport@pokerlogger.app',
              style: GoogleFonts.inter(
                color: Colors.white.withOpacity(0.7),
                fontSize: 13,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: GoogleFonts.inter(
                color: const Color(0xFF87ED81),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSignOutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'Sign Out',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'Are you sure you want to sign out?',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                color: Colors.white.withOpacity(0.7),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await AuthService.signOut();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => IntroScreen()),
                  (route) => false,
                );
              }
            },
            child: Text(
              'Sign Out',
              style: GoogleFonts.inter(
                color: const Color(0xFFFF6B6B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Data class for menu items
class _MenuItemData {
  final String? iconPath;
  final IconData fallbackIcon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  _MenuItemData({
    this.iconPath,
    required this.fallbackIcon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });
}
