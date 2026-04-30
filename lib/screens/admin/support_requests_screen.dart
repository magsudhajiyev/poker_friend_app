import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../l10n/app_localizations.dart';
import '../../design_system/constants/colors.dart';
import '../../design_system/components/backgrounds/gradient_background.dart';
import '../../models/support_request.dart';
import '../../services/support_request_service.dart';

class SupportRequestsScreen extends StatefulWidget {
  const SupportRequestsScreen({super.key});

  @override
  State<SupportRequestsScreen> createState() => _SupportRequestsScreenState();
}

class _SupportRequestsScreenState extends State<SupportRequestsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<SupportRequest> _allRequests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
      final requests = await SupportRequestService.getAllRequests();
      setState(() {
        _allRequests = requests;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  List<SupportRequest> _getFilteredRequests(int tabIndex) {
    switch (tabIndex) {
      case 0:
        return _allRequests;
      case 1:
        return _allRequests.where((r) => r.isPending).toList();
      case 2:
        return _allRequests.where((r) => r.isResolved || r.isRejected).toList();
      default:
        return _allRequests;
    }
  }

  Future<void> _resolveRequest(SupportRequest request) async {
    final l10n = AppLocalizations.of(context);
    final responseController = TextEditingController();

    final response = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.backgroundSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          l10n.supportRequestsResolveTitle,
          style: GoogleFonts.ibmPlexSans(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.supportRequestsResolveBody,
              style: GoogleFonts.ibmPlexSans(color: const Color(0xFF8C8C8C), fontSize: 14),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: responseController,
              maxLines: 3,
              style: GoogleFonts.ibmPlexSans(color: Colors.white, fontSize: 15),
              decoration: InputDecoration(
                hintText: l10n.supportRequestsResponseHint,
                hintStyle: GoogleFonts.ibmPlexSans(color: const Color(0xFF8C8C8C)),
                filled: true,
                fillColor: AppColors.backgroundPaper,
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
              l10n.commonCancel,
              style: GoogleFonts.ibmPlexSans(color: const Color(0xFF8C8C8C)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, responseController.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF87ED81),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(l10n.supportRequestsResolve, style: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (response == null) return;

    _showLoadingDialog();
    try {
      await SupportRequestService.resolveRequest(
        request.id,
        response: response.isEmpty ? null : response,
      );
      Navigator.pop(context);
      _loadRequests();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.supportRequestsResolved, style: GoogleFonts.ibmPlexSans(color: Colors.white)),
          backgroundColor: const Color(0xFF87ED81),
        ),
      );
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).commonErrorGeneric('$e'), style: GoogleFonts.ibmPlexSans(color: Colors.white)),
          backgroundColor: const Color(0xFFD55A41),
        ),
      );
    }
  }

  Future<void> _rejectRequest(SupportRequest request) async {
    final l10n = AppLocalizations.of(context);
    final reasonController = TextEditingController();

    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.backgroundSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          l10n.supportRequestsRejectTitle,
          style: GoogleFonts.ibmPlexSans(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.supportRequestsRejectBody,
              style: GoogleFonts.ibmPlexSans(color: const Color(0xFF8C8C8C), fontSize: 14),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 3,
              style: GoogleFonts.ibmPlexSans(color: Colors.white, fontSize: 15),
              decoration: InputDecoration(
                hintText: l10n.supportRequestsRejectHint,
                hintStyle: GoogleFonts.ibmPlexSans(color: const Color(0xFF8C8C8C)),
                filled: true,
                fillColor: AppColors.backgroundPaper,
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
              l10n.commonCancel,
              style: GoogleFonts.ibmPlexSans(color: const Color(0xFF8C8C8C)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.trim().isNotEmpty) {
                Navigator.pop(context, reasonController.text.trim());
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD55A41),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(l10n.supportRequestsReject, style: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (reason == null) return;

    _showLoadingDialog();
    try {
      await SupportRequestService.rejectRequest(request.id, reason);
      Navigator.pop(context);
      _loadRequests();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.supportRequestsRejected, style: GoogleFonts.ibmPlexSans(color: Colors.white)),
          backgroundColor: const Color(0xFFD55A41),
        ),
      );
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).commonErrorGeneric('$e'), style: GoogleFonts.ibmPlexSans(color: Colors.white)),
          backgroundColor: const Color(0xFFD55A41),
        ),
      );
    }
  }

  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF89F1EC)),
      ),
    );
  }

  void _showRequestDetails(SupportRequest request) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.backgroundSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Expanded(
              child: Text(
                request.subject,
                style: GoogleFonts.ibmPlexSans(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
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
              _buildDetailRow(l10n.supportRequestsCategory, request.category),
              _buildDetailRow(l10n.supportRequestsUser, request.userName),
              _buildDetailRow(l10n.supportRequestsEmail, request.userEmail),
              _buildDetailRow(
                l10n.supportRequestsSubmitted,
                DateFormat('MMM d, yyyy HH:mm').format(request.submittedAt),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.supportRequestsDescription,
                style: GoogleFonts.ibmPlexSans(
                  color: const Color(0xFF8C8C8C),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.backgroundPaper,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  request.description,
                  style: GoogleFonts.ibmPlexSans(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ),
              if (request.adminResponse != null) ...[
                const SizedBox(height: 12),
                Text(
                  l10n.supportRequestsAdminResponse,
                  style: GoogleFonts.ibmPlexSans(
                    color: const Color(0xFF8C8C8C),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: request.isResolved
                        ? const Color(0xFF87ED81).withValues(alpha: 0.1)
                        : const Color(0xFFD55A41).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    request.adminResponse!,
                    style: GoogleFonts.ibmPlexSans(
                      color: request.isResolved
                          ? const Color(0xFF87ED81)
                          : const Color(0xFFD55A41),
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
            child: Text(
              l10n.commonClose,
              style: GoogleFonts.ibmPlexSans(color: const Color(0xFF89F1EC)),
            ),
          ),
          if (request.isPending) ...[
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _rejectRequest(request);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD55A41),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(l10n.supportRequestsReject, style: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.w600)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _resolveRequest(request);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF87ED81),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(l10n.supportRequestsResolve, style: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.w600)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: GoogleFonts.ibmPlexSans(
                color: const Color(0xFF8C8C8C),
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.ibmPlexSans(
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
      backgroundColor: AppColors.backgroundPaper,
      body: Stack(
        children: [
          const GradientBackground(),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                _buildTabBar(),
                const SizedBox(height: 8),
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(color: Color(0xFF89F1EC)),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadRequests,
                          color: const Color(0xFF89F1EC),
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              _buildRequestList(0),
                              _buildRequestList(1),
                              _buildRequestList(2),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: Color(0xFF101115),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_back,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            AppLocalizations.of(context).supportRequestsTitle,
            style: GoogleFonts.ibmPlexSans(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    final pendingCount = _allRequests.where((r) => r.isPending).length;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      decoration: BoxDecoration(
        color: AppColors.backgroundSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: const Color(0xFF89F1EC),
          borderRadius: BorderRadius.circular(10),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Colors.black,
        unselectedLabelColor: const Color(0xFF8C8C8C),
        labelStyle: GoogleFonts.ibmPlexSans(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: GoogleFonts.ibmPlexSans(
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        padding: const EdgeInsets.all(4),
        tabs: [
          Tab(text: AppLocalizations.of(context).supportRequestsAll),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(AppLocalizations.of(context).supportRequestsPending, overflow: TextOverflow.ellipsis),
                ),
                if (pendingCount > 0) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD55A41),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '$pendingCount',
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 10,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Tab(text: AppLocalizations.of(context).supportRequestsClosed),
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
              color: Colors.white.withValues(alpha: 0.15),
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context).supportRequestsNoRequests,
              style: GoogleFonts.ibmPlexSans(
                color: const Color(0xFF8C8C8C),
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: requests.length,
      itemBuilder: (context, index) => _buildRequestCard(requests[index]),
    );
  }

  Widget _buildRequestCard(SupportRequest request) {
    return GestureDetector(
      onTap: () => _showRequestDetails(request),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.backgroundSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF1C1F21), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildCategoryBadge(request.category),
                const Spacer(),
                _buildStatusBadge(request.status),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              request.subject,
              style: GoogleFonts.ibmPlexSans(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              request.description,
              style: GoogleFonts.ibmPlexSans(
                color: const Color(0xFF8C8C8C),
                fontSize: 13,
                height: 1.4,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.person_outline, size: 14, color: Colors.white.withValues(alpha: 0.3)),
                const SizedBox(width: 4),
                Text(
                  request.userName,
                  style: GoogleFonts.ibmPlexSans(
                    color: const Color(0xFF8C8C8C),
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                Text(
                  DateFormat('MMM d, HH:mm').format(request.submittedAt),
                  style: GoogleFonts.ibmPlexSans(
                    color: const Color(0xFF8C8C8C),
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
                    child: GestureDetector(
                      onTap: () => _rejectRequest(request),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFD55A41)),
                        ),
                        child: Center(
                          child: Text(
                            AppLocalizations.of(context).supportRequestsReject,
                            style: GoogleFonts.ibmPlexSans(
                              color: const Color(0xFFD55A41),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _resolveRequest(request),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF87ED81),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            AppLocalizations.of(context).supportRequestsResolve,
                            style: GoogleFonts.ibmPlexSans(
                              color: Colors.black,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
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

  Widget _buildCategoryBadge(String category) {
    Color color;
    switch (category) {
      case 'Bug Report':
        color = const Color(0xFFD55A41);
        break;
      case 'Feature Request':
        color = const Color(0xFF89F1EC);
        break;
      case 'Account Issue':
        color = const Color(0xFFE8B55A);
        break;
      default:
        color = const Color(0xFF8C8C8C);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        category,
        style: GoogleFonts.ibmPlexSans(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildStatusBadge(SupportRequestStatus status) {
    final l10n = AppLocalizations.of(context);
    Color color;
    String label;

    switch (status) {
      case SupportRequestStatus.pending:
        color = const Color(0xFFE8B55A);
        label = l10n.supportRequestsPendingBadge;
        break;
      case SupportRequestStatus.resolved:
        color = const Color(0xFF87ED81);
        label = l10n.supportRequestsResolvedBadge;
        break;
      case SupportRequestStatus.rejected:
        color = const Color(0xFFD55A41);
        label = l10n.supportRequestsRejectedBadge;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: GoogleFonts.ibmPlexSans(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
