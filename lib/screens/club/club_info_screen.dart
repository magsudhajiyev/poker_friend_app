import 'package:flutter/material.dart';
import '../../design_system/poker_friend_theme.dart';
import '../../models/club.dart';
import '../../models/club_member.dart';
import '../../services/club_service.dart';

/// Club info screen for regular members (read-only view)
class ClubInfoScreen extends StatefulWidget {
  final Club club;

  const ClubInfoScreen({
    Key? key,
    required this.club,
  }) : super(key: key);

  @override
  State<ClubInfoScreen> createState() => _ClubInfoScreenState();
}

class _ClubInfoScreenState extends State<ClubInfoScreen> {
  bool _isLoading = true;
  List<ClubMember> _members = [];

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    setState(() => _isLoading = true);
    try {
      final members = await ClubService.getMembers(widget.club.id);
      setState(() {
        _members = members;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PokerFriendColors.dark1,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: PokerFriendColors.purple,
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildClubInfoSection(),
                          const SizedBox(height: 32),
                          _buildMembersSection(),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: PokerFriendColors.dark3,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.arrow_back,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Text(
              'Club Info',
              style: TextStyle(
                fontSize: 24,
                color: Colors.white,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClubInfoSection() {
    final club = widget.club;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'About',
          style: TextStyle(
            fontSize: 18,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: PokerFriendColors.dark3,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Club name
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: PokerFriendColors.purple.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.home,
                      color: PokerFriendColors.purple,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      club.name,
                      style: const TextStyle(
                        fontSize: 22,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),

              // Description
              if (club.description != null && club.description!.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  club.description!,
                  style: TextStyle(
                    fontSize: 15,
                    color: PokerFriendColors.dark11,
                    height: 1.5,
                  ),
                ),
              ],

              // Divider
              if (club.address != null || club.phone != null) ...[
                const SizedBox(height: 20),
                Divider(color: PokerFriendColors.dark5),
                const SizedBox(height: 16),
              ],

              // Address
              if (club.address != null && club.address!.isNotEmpty)
                _buildInfoRow(Icons.location_on, club.address!),

              // Phone
              if (club.phone != null && club.phone!.isNotEmpty) ...[
                if (club.address != null && club.address!.isNotEmpty)
                  const SizedBox(height: 12),
                _buildInfoRow(Icons.phone, club.phone!),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: PokerFriendColors.dark9, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 15,
              color: PokerFriendColors.dark11,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMembersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Members (${_members.length})',
          style: const TextStyle(
            fontSize: 18,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        if (_members.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: PokerFriendColors.dark3,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              'No members found',
              style: TextStyle(color: PokerFriendColors.dark9),
              textAlign: TextAlign.center,
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: PokerFriendColors.dark3,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: List.generate(_members.length, (index) {
                final member = _members[index];
                return Column(
                  children: [
                    _buildMemberRow(member),
                    if (index < _members.length - 1)
                      Divider(
                        height: 1,
                        color: PokerFriendColors.dark5,
                        indent: 70,
                      ),
                  ],
                );
              }),
            ),
          ),
      ],
    );
  }

  Widget _buildMemberRow(ClubMember member) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _getRoleColor(member.role).withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                (member.displayName ?? 'U')[0].toUpperCase(),
                style: TextStyle(
                  fontSize: 18,
                  color: _getRoleColor(member.role),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              member.displayName ?? 'Unknown',
              style: const TextStyle(
                fontSize: 15,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _getRoleColor(member.role).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              member.role.name.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                color: _getRoleColor(member.role),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getRoleColor(ClubRole role) {
    switch (role) {
      case ClubRole.owner:
        return PokerFriendColors.yellow;
      case ClubRole.admin:
        return PokerFriendColors.purple;
      case ClubRole.dealer:
        return PokerFriendColors.blue;
      case ClubRole.player:
        return PokerFriendColors.green;
    }
  }
}
