import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:printing/printing.dart';
import '../providers/auth_providers.dart';
import '../services/leave_credit_service.dart';
import '../services/leave_application_service.dart';
import '../users/login_page.dart';
import '../screentabs/apply_for_leave.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _creditData;
  int _selectedIndex = 0;

  List<dynamic> _pendingApplications = [];
  bool _isLoadingPending = true;

  @override
  void initState() {
    super.initState();
    _loadCredits();
    _loadPendingApplications();
  }

  Future<void> _loadCredits() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.token;

    if (token == null) {
      if (!mounted) return;
      setState(() {
        _errorMessage = "You are not logged in.";
        _isLoading = false;
      });
      return;
    }

    final result = await LeaveCreditService.getCredits(token);

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (result["success"]) {
        _creditData = result["data"];
      } else {
        _errorMessage = result["message"];
      }
    });
  }

  Future<void> _loadPendingApplications() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.token;

    if (token == null) {
      if (!mounted) return;
      setState(() => _isLoadingPending = false);
      return;
    }

    final result = await LeaveApplicationService.getMyApplications(
      token: token,
      status: 'pending',
    );

    if (!mounted) return;
    setState(() {
      _isLoadingPending = false;
      if (result['success'] == true) {
        _pendingApplications = result['data'] as List<dynamic>;
      }
    });
  }

  Future<void> _viewPendingPdf(int applicationId) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.token;
    if (token == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.deepPurple)),
    );

    final result = await LeaveApplicationService.getApplicationPdfBytes(
      applicationId: applicationId,
      token: token,
    );

    if (!mounted) return;
    Navigator.pop(context);

    if (result['success'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? 'Unable to load PDF.')),
      );
      return;
    }

    final bytes = result['bytes'];
    await Printing.layoutPdf(
      onLayout: (format) async => bytes,
      name: 'leave-application-$applicationId.pdf',
    );
  }

  String _formatDate(String? isoDate) {
    if (isoDate == null || isoDate.isEmpty) return '';
    try {
      final date = DateTime.parse(isoDate);
      return '${date.month.toString().padLeft(2, '0')}/'
          '${date.day.toString().padLeft(2, '0')}/${date.year}';
    } catch (_) {
      return isoDate;
    }
  }

  Future<void> _goToApplyLeave() async {
    List<dynamic> credits = [];

    if (_creditData is Map) {
      if (_creditData!["credits"] is List) {
        credits = _creditData!["credits"];
      } else if (_creditData!["data"] is List) {
        credits = _creditData!["data"];
      }
    } else if (_creditData is List) {
      credits = _creditData as List<dynamic>;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ApplyForLeave(leaveTypes: credits),
      ),
    );

    if (result != null) {
      await _loadCredits();
      await _loadPendingApplications();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Leave application submitted! It is pending approval.'),
          ),
        );
      }
    }
  }

  double _toDouble(dynamic value) =>
      double.tryParse(value?.toString() ?? '0') ?? 0.0;

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).user;
    final List<dynamic> credits = () {
      if (_creditData is Map) {
        if (_creditData!["credits"] is List) return _creditData!["credits"];
        if (_creditData!["data"] is List) return _creditData!["data"];
      } else if (_creditData is List) {
        return _creditData as List<dynamic>;
      }
      return <dynamic>[];
    }();

    final totalDays = credits.fold(0.0, (sum, c) => sum + _toDouble(c["total_credits"]));
    final usedDays  = credits.fold(0.0, (sum, c) => sum + _toDouble(c["used_credits"]));
    final remaining = totalDays - usedDays;
    final overallProgress = totalDays > 0
        ? (usedDays / totalDays).clamp(0.0, 1.0)
        : 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFFEEF0F5),
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text('Home', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Colors.white),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Confirm Logout'),
                  content: const Text('Do you want to logout?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('No'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Confirm'),
                    ),
                  ],
                ),
              );
              if (confirm == true && context.mounted) {
                Provider.of<AuthProvider>(context, listen: false).logout();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                );
              }
            },
          ),
        ],
      ),
      bottomNavigationBar: BottomAppBar(
        color: Colors.white,
        elevation: 8,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _bottomNavItem(icon: Icons.home_rounded, label: 'Home', index: 0),
              const SizedBox(width: 48),
              _bottomNavItem(icon: Icons.person_outline_rounded, label: 'Profile', index: 1),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.deepPurple,
        onPressed: _goToApplyLeave,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.deepPurple))
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)))
              : RefreshIndicator(
                  onRefresh: () async {
                    await _loadCredits();
                    await _loadPendingApplications();
                  },
                  color: Colors.deepPurple,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome, ${user?["username"] ?? "User"}!',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_creditData?["employee"] ?? ""} · ${_creditData?["year"] ?? ""}',
                              style: const TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1E3A5F), Color(0xFF2D5491)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'LEAVE BALANCE — ${_creditData?["year"] ?? DateTime.now().year}',
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Total Credits', style: TextStyle(color: Colors.white60, fontSize: 12)),
                                        const SizedBox(height: 4),
                                        Text(
                                          totalDays % 1 == 0 ? '${totalDays.toInt()}' : '$totalDays',
                                          style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Remaining', style: TextStyle(color: Colors.white60, fontSize: 12)),
                                        const SizedBox(height: 4),
                                        Text(
                                          remaining % 1 == 0 ? '${remaining.toInt()}' : '$remaining',
                                          style: const TextStyle(color: Color(0xFF4EEAAA), fontSize: 32, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text('By Leave Type', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF1E3A5F))),
                      const SizedBox(height: 14),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: credits.length,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.1,
                        ),
                        itemBuilder: (context, index) {
                          final credit = credits[index];
                          final rem = _toDouble(credit["remaining_balance"]);
                          final tot = _toDouble(credit["total_credits"]);

                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  credit["leave_type"] ?? credit["name"] ?? "",
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E3A5F)),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  rem % 1 == 0 ? '${rem.toInt()}' : '$rem',
                                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.deepPurple),
                                ),
                                Text('of ${tot % 1 == 0 ? tot.toInt() : tot} days left', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      const Text('Pending Requests', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF1E3A5F))),
                      const SizedBox(height: 14),
                      if (_isLoadingPending)
                        const Center(child: CircularProgressIndicator(color: Colors.deepPurple))
                      else if (_pendingApplications.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                          child: const Center(child: Text('No pending requests.', style: TextStyle(color: Color(0xFF8A97A8)))),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _pendingApplications.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final app = _pendingApplications[index] as Map<String, dynamic>;
                            final leaveType = app['leave_type_name'] ?? 'Leave';
                            final days = app['days_applied']?.toString() ?? '0';
                            final start = _formatDate(app['start_date']?.toString());
                            final end = _formatDate(app['end_date']?.toString());
                            final id = app['id'];

                            return InkWell(
                              onTap: id == null ? null : () => _viewPendingPdf(id as int),
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(leaveType, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF1E3A5F))),
                                          const SizedBox(height: 2),
                                          Text('$start – $end · $days day(s)', style: const TextStyle(fontSize: 12, color: Color(0xFF8A97A8))),
                                        ],
                                      ),
                                    ),
                                    const Icon(Icons.picture_as_pdf_outlined, color: Color(0xFF8A97A8), size: 20),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
    );
  }

  Widget _bottomNavItem({required IconData icon, required String label, required int index}) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: isSelected ? Colors.deepPurple : Colors.grey, size: 24),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 11, color: isSelected ? Colors.deepPurple : Colors.grey)),
        ],
      ),
    );
  }
}