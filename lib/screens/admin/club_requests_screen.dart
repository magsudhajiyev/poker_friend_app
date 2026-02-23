import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../design_system/poker_friend_theme.dart';
import '../../models/club_request.dart';
import '../../services/club_request_service.dart';

/// Screen for app admins to manage club registration requests
class ClubRequestsScreen extends StatefulWidget {
  const ClubRequestsScreen({Key? key}) : super(key: key);

  @override
  State<ClubRequestsScreen> createState() => _ClubRequestsScreenState();
}

class _ClubRequestsScreenState extends State<ClubRequestsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<ClubRequest> _allRequests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadRequests();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadRequests() async {
    setState(() => _isLoading = true);
    try {
      final requests = await ClubRequestService.getAllRequests();
      setState(() {
        _allRequests = requests;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  List<ClubRequest> _getFilteredRequests(int tabIndex) {
    switch (tabIndex) {
      case 0: // All
        return _allRequests;
      case 1: // Pending
        return _allRequests.where((r) => r.isPending).toList();
      case 2: // Approved
        return _allRequests.where((r) => r.isApproved).toList();
      case 3: // Rejected
        return _allRequests.where((r) => r.isRejected).toList();
      default:
        return _allRequests;
    }
  }

  Future<void> _approveRequest(ClubRequest request) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: PokerFriendColors.dark3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Approve Request',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to approve "${request.clubName}"?\n\nThis will create the club and notify ${request.adminEmail}.',
          style: TextStyle(color: PokerFriendColors.dark11),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: PokerFriendColors.dark9),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: PokerFriendColors.green,
            ),
            child: const Text('Approve'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      _showLoadingDialog();
      try {
        await ClubRequestService.approveRequest(request.id);
        Navigator.pop(context); // Close loading
        _loadRequests();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${request.clubName} has been approved!'),
            backgroundColor: PokerFriendColors.green,
          ),
        );
      } catch (e) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: PokerFriendColors.red,
          ),
        );
      }
    }
  }

  Future<void> _rejectRequest(ClubRequest request) async {
    final reasonController = TextEditingController();

    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: PokerFriendColors.dark3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Reject Request',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Please provide a reason for rejecting "${request.clubName}":',
              style: TextStyle(color: PokerFriendColors.dark11),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Reason for rejection...',
                hintStyle: TextStyle(color: PokerFriendColors.dark9),
                filled: true,
                fillColor: PokerFriendColors.dark1,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: Text(
              'Cancel',
              style: TextStyle(color: PokerFriendColors.dark9),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.trim().isNotEmpty) {
                Navigator.pop(context, reasonController.text.trim());
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: PokerFriendColors.red,
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (reason != null) {
      _showLoadingDialog();
      try {
        await ClubRequestService.rejectRequest(request.id, reason);
        Navigator.pop(context); // Close loading
        _loadRequests();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${request.clubName} has been rejected.'),
            backgroundColor: PokerFriendColors.red,
          ),
        );
      } catch (e) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: PokerFriendColors.red,
          ),
        );
      }
    }
  }

  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: PokerFriendColors.purple),
      ),
    );
  }

  void _showRequestDetails(ClubRequest request) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: PokerFriendColors.dark3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Expanded(
              child: Text(
                request.clubName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            _buildStatusBadge(request.status),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Address', request.address),
              _buildDetailRow('Phone', request.phone),
              _buildDetailRow('Admin Email', request.adminEmail),
              const Divider(color: PokerFriendColors.dark5),
              _buildDetailRow('Requested By', request.requestedByName),
              _buildDetailRow('Requester Email', request.requestedByEmail),
              _buildDetailRow(
                'Requested At',
                DateFormat('MMM d, yyyy HH:mm').format(request.requestedAt),
              ),
              if (request.reviewedAt != null) ...[
                const Divider(color: PokerFriendColors.dark5),
                _buildDetailRow(
                  'Reviewed At',
                  DateFormat('MMM d, yyyy HH:mm').format(request.reviewedAt!),
                ),
              ],
              if (request.rejectionReason != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Rejection Reason:',
                  style: TextStyle(
                    color: PokerFriendColors.dark9,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: PokerFriendColors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    request.rejectionReason!,
                    style: TextStyle(
                      color: PokerFriendColors.red,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Close',
              style: TextStyle(color: PokerFriendColors.purple),
            ),
          ),
          if (request.isPending) ...[
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _rejectRequest(request);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: PokerFriendColors.red,
              ),
              child: const Text('Reject'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _approveRequest(request);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: PokerFriendColors.green,
              ),
              child: const Text('Approve'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                color: PokerFriendColors.dark9,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PokerFriendColors.dark1,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildTabBar(),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: PokerFriendColors.purple,
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadRequests,
                      color: PokerFriendColors.purple,
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildRequestList(0),
                          _buildRequestList(1),
                          _buildRequestList(2),
                          _buildRequestList(3),
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
              'Club Requests',
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

  Widget _buildTabBar() {
    final pendingCount = _allRequests.where((r) => r.isPending).length;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: PokerFriendColors.dark3,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: PokerFriendColors.purple,
          borderRadius: BorderRadius.circular(10),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Colors.white,
        unselectedLabelColor: PokerFriendColors.dark9,
        labelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        padding: const EdgeInsets.all(4),
        tabs: [
          const Tab(text: 'All'),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Flexible(
                  child: Text(
                    'Pending',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (pendingCount > 0) ...[
                  const SizedBox(width: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: PokerFriendColors.red,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '$pendingCount',
                      style: const TextStyle(
                        fontSize: 9,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Tab(text: 'Approved'),
          const Tab(text: 'Rejected'),
        ],
      ),
    );
  }

  Widget _buildRequestList(int tabIndex) {
    final requests = _getFilteredRequests(tabIndex);

    if (requests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 64,
              color: PokerFriendColors.dark5,
            ),
            const SizedBox(height: 16),
            Text(
              'No requests',
              style: TextStyle(
                color: PokerFriendColors.dark9,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: requests.length,
      itemBuilder: (context, index) => _buildRequestCard(requests[index]),
    );
  }

  Widget _buildRequestCard(ClubRequest request) {
    return GestureDetector(
      onTap: () => _showRequestDetails(request),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: PokerFriendColors.dark3,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    request.clubName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                _buildStatusBadge(request.status),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.location_on,
                  size: 14,
                  color: PokerFriendColors.dark9,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    request.address,
                    style: TextStyle(
                      color: PokerFriendColors.dark11,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.email,
                  size: 14,
                  color: PokerFriendColors.dark9,
                ),
                const SizedBox(width: 4),
                Text(
                  request.adminEmail,
                  style: TextStyle(
                    color: PokerFriendColors.dark11,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                Text(
                  DateFormat('MMM d').format(request.requestedAt),
                  style: TextStyle(
                    color: PokerFriendColors.dark9,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            if (request.isPending) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _rejectRequest(request),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: PokerFriendColors.red,
                        side: const BorderSide(color: PokerFriendColors.red),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Reject'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _approveRequest(request),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: PokerFriendColors.green,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Approve'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(ClubRequestStatus status) {
    Color color;
    String label;

    switch (status) {
      case ClubRequestStatus.pending:
        color = PokerFriendColors.yellow;
        label = 'PENDING';
        break;
      case ClubRequestStatus.approved:
        color = PokerFriendColors.green;
        label = 'APPROVED';
        break;
      case ClubRequestStatus.rejected:
        color = PokerFriendColors.red;
        label = 'REJECTED';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
