import 'package:flutter/material.dart';
import '../models/visa_request.dart';
import '../models/office.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';

class OfficeDashboard extends StatefulWidget {
  final String officeId;

  const OfficeDashboard({Key? key, required this.officeId}) : super(key: key);

  @override
  _OfficeDashboardState createState() => _OfficeDashboardState();
}

class _OfficeDashboardState extends State<OfficeDashboard> with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final DatabaseService _databaseService = DatabaseService();

  late TabController _tabController;
  
  Office? _office;
  List<VisaRequest> _activeRequests = [];
  List<VisaRequest> _completedRequests = [];
  
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      // Load office profile
      final user = await _databaseService.getUserById(widget.officeId);
      
      // In a real app, we would get the office profile here
      // For now, we'll create a mock office
      final office = Office(
        id: widget.officeId,
        name: user.name,
        email: user.email,
        phoneNumber: user.phoneNumber,
        address: 'Office Address',
        createdAt: DateTime.now(),
      );
      
      // Load visa requests assigned to this office
      final requests = await _databaseService.getOfficeVisaRequests(widget.officeId);

      // Filter by status
      final activeRequests = <VisaRequest>[];
      final completedRequests = <VisaRequest>[];

      for (final request in requests) {
        if (request.status == VisaStatus.completed || 
            request.status == VisaStatus.rejected) {
          completedRequests.add(request);
        } else {
          activeRequests.add(request);
        }
      }

      setState(() {
        _office = office;
        _activeRequests = activeRequests;
        _completedRequests = completedRequests;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load data: $e';
      });
    }
  }

  Future<void> _signOut() async {
    try {
      await _authService.signOut();
      Navigator.pushReplacementNamed(context, '/login');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error signing out: $e')),
      );
    }
  }

  Future<void> _updateRequestStatus(VisaRequest request, VisaStatus newStatus) async {
    try {
      setState(() {
        _isLoading = true;
      });

      await _databaseService.updateVisaRequest(
        visaRequestId: request.id,
        status: newStatus,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Status updated to ${newStatus.toString().split('.').last}')),
      );

      await _loadData();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to update status: $e';
      });
    }
  }

  Future<void> _completeRequest(VisaRequest request) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Complete Visa Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Request #${request.id.substring(0, 8)}'),
            const SizedBox(height: 16),
            const Text('Are you sure you want to mark this request as completed?'),
            const Text('This will indicate that the visa has been issued.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Complete'),
          ),
        ],
      ),
    );

    if (result == true) {
      await _updateRequestStatus(request, VisaStatus.completed);
    }
  }

  Future<void> _rejectRequest(VisaRequest request) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Visa Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Request #${request.id.substring(0, 8)}'),
            const SizedBox(height: 16),
            const Text('Are you sure you want to reject this request?'),
            const Text('Please explain the reason in the chat.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (result == true) {
      await _updateRequestStatus(request, VisaStatus.rejected);
    }
  }

  Future<void> _startProcessing(VisaRequest request) async {
    await _updateRequestStatus(request, VisaStatus.processing);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_office?.name ?? 'Office Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Active'),
            Tab(text: 'Completed'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _errorMessage,
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadData,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildRequestsList(_activeRequests, isActive: true),
                    _buildRequestsList(_completedRequests),
                  ],
                ),
    );
  }

  Widget _buildRequestsList(List<VisaRequest> requests, {bool isActive = false}) {
    if (requests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.inbox,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              'No ${isActive ? 'active' : 'completed'} requests',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: requests.length,
        itemBuilder: (context, index) {
          final request = requests[index];
          return _buildRequestCard(request, isActive: isActive);
        },
      ),
    );
  }

  Widget _buildRequestCard(VisaRequest request, {bool isActive = false}) {
    Color statusColor;
    IconData statusIcon;

    switch (request.status) {
      case VisaStatus.assigned:
        statusColor = Colors.orange;
        statusIcon = Icons.new_releases;
        break;
      case VisaStatus.processing:
        statusColor = Colors.blue;
        statusIcon = Icons.sync;
        break;
      case VisaStatus.completed:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case VisaStatus.rejected:
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help_outline;
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16.0),
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(
            context,
            '/chat/${request.id}',
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    statusIcon,
                    color: statusColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Request #${request.id.substring(0, 8)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const Spacer(),
                  Chip(
                    label: Text(
                      request.status.toString().split('.').last,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    backgroundColor: statusColor.withOpacity(0.1),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
              const Divider(),
              _buildInfoRow('Passport:', request.passportNumber),
              _buildInfoRow('Created:', _formatDate(request.createdAt)),
              _buildInfoRow(
                'Payment:',
                request.isPaid ? 'Verified' : 'Pending',
              ),
              const SizedBox(height: 8),
              if (isActive)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (request.status == VisaStatus.assigned)
                      TextButton.icon(
                        icon: const Icon(Icons.sync),
                        label: const Text('Start Processing'),
                        onPressed: () => _startProcessing(request),
                      ),
                    if (request.status == VisaStatus.processing) ...[
                      TextButton.icon(
                        icon: const Icon(Icons.cancel, color: Colors.red),
                        label: const Text('Reject', style: TextStyle(color: Colors.red)),
                        onPressed: () => _rejectRequest(request),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        icon: const Icon(Icons.check_circle, color: Colors.green),
                        label: const Text('Complete', style: TextStyle(color: Colors.green)),
                        onPressed: () => _completeRequest(request),
                      ),
                    ],
                    const SizedBox(width: 8),
                    TextButton.icon(
                      icon: const Icon(Icons.chat),
                      label: const Text('Chat'),
                      onPressed: () {
                        Navigator.pushNamed(
                          context,
                          '/chat/${request.id}',
                        );
                      },
                    ),
                  ],
                ),
              if (!isActive)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.chat),
                      label: const Text('View Chat'),
                      onPressed: () {
                        Navigator.pushNamed(
                          context,
                          '/chat/${request.id}',
                        );
                      },
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}