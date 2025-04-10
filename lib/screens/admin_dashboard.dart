import 'package:flutter/material.dart';
import 'package:visa_mediation_app/models/visa_request.dart';
import 'package:visa_mediation_app/models/office.dart';
import 'package:visa_mediation_app/services/auth_service.dart';
import 'package:visa_mediation_app/services/database_service.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({Key? key}) : super(key: key);

  @override
  _AdminDashboardState createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final DatabaseService _databaseService = DatabaseService();

  late TabController _tabController;
  
  List<VisaRequest> _pendingRequests = [];
  List<VisaRequest> _activeRequests = [];
  List<VisaRequest> _completedRequests = [];
  List<Office> _offices = [];
  
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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

      // Load all visa requests
      final allRequests = await _databaseService.getAllVisaRequests();
      
      // Load all offices
      final offices = await _databaseService.getAllOffices();

      // Filter requests by status
      final pendingRequests = <VisaRequest>[];
      final activeRequests = <VisaRequest>[];
      final completedRequests = <VisaRequest>[];

      for (final request in allRequests) {
        switch (request.status) {
          case VisaStatus.pending:
          case VisaStatus.documentsPending:
          case VisaStatus.paymentPending:
          case VisaStatus.paymentVerified:
            pendingRequests.add(request);
            break;
          case VisaStatus.assigned:
          case VisaStatus.processing:
            activeRequests.add(request);
            break;
          case VisaStatus.completed:
          case VisaStatus.rejected:
            completedRequests.add(request);
            break;
        }
      }

      setState(() {
        _pendingRequests = pendingRequests;
        _activeRequests = activeRequests;
        _completedRequests = completedRequests;
        _offices = offices;
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

  Future<void> _assignToOffice(VisaRequest request) async {
    if (_offices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No available offices')),
      );
      return;
    }

    final availableOffices = _offices.where((office) => office.canAcceptApplication()).toList();
    
    if (availableOffices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All offices are at max capacity')),
      );
      return;
    }

    final selectedOffice = await showDialog<Office>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Assign to Office'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: availableOffices.length,
            itemBuilder: (context, index) {
              final office = availableOffices[index];
              return ListTile(
                title: Text(office.name),
                subtitle: Text('Active: ${office.currentActiveApplications}/${office.maxActiveApplications}'),
                onTap: () {
                  Navigator.pop(context, office);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (selectedOffice != null) {
      try {
        setState(() {
          _isLoading = true;
        });

        await _databaseService.updateVisaRequest(
          visaRequestId: request.id,
          officeId: selectedOffice.id,
          status: VisaStatus.assigned,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Assigned to ${selectedOffice.name}')),
        );

        await _loadData();
      } catch (e) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to assign request: $e';
        });
      }
    }
  }

  Future<void> _verifyPayment(VisaRequest request) async {
    // In a real app, we would show the payment screenshot and details here
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Verify Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Request #${request.id.substring(0, 8)}'),
            const SizedBox(height: 8),
            Text('Amount: EGP ${request.paymentAmount}'),
            const SizedBox(height: 8),
            Text('Reference: ${request.paymentReference ?? 'N/A'}'),
            const SizedBox(height: 16),
            const Text('Would you like to verify this payment?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Reject'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Verify'),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        setState(() {
          _isLoading = true;
        });

        await _databaseService.updateVisaRequest(
          visaRequestId: request.id,
          status: VisaStatus.paymentVerified,
          isPaid: true,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment verified')),
        );

        await _loadData();
      } catch (e) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to verify payment: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
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
            Tab(text: 'Pending'),
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
                    _buildRequestsList(_pendingRequests, isPending: true),
                    _buildRequestsList(_activeRequests),
                    _buildRequestsList(_completedRequests),
                  ],
                ),
    );
  }

  Widget _buildRequestsList(List<VisaRequest> requests, {bool isPending = false}) {
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
              'No ${isPending ? 'pending' : _tabController.index == 1 ? 'active' : 'completed'} requests',
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
          return _buildRequestCard(request, isPending: isPending);
        },
      ),
    );
  }

  Widget _buildRequestCard(VisaRequest request, {bool isPending = false}) {
    Color statusColor;
    IconData statusIcon;

    switch (request.status) {
      case VisaStatus.pending:
        statusColor = Colors.orange;
        statusIcon = Icons.hourglass_empty;
        break;
      case VisaStatus.documentsPending:
        statusColor = Colors.orange;
        statusIcon = Icons.description_outlined;
        break;
      case VisaStatus.paymentPending:
        statusColor = Colors.orange;
        statusIcon = Icons.payment;
        break;
      case VisaStatus.paymentVerified:
        statusColor = Colors.blue;
        statusIcon = Icons.check_circle_outline;
        break;
      case VisaStatus.assigned:
        statusColor = Colors.blue;
        statusIcon = Icons.person_outline;
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
              if (request.officeId != null)
                _buildInfoRow('Office:', _getOfficeName(request.officeId!)),
              _buildInfoRow(
                'Payment:',
                request.isPaid ? 'Verified' : 'Pending',
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (isPending && request.status == VisaStatus.paymentPending && !request.isPaid)
                    TextButton.icon(
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Verify Payment'),
                      onPressed: () => _verifyPayment(request),
                    ),
                  if (isPending && request.status == VisaStatus.paymentVerified && request.officeId == null)
                    TextButton.icon(
                      icon: const Icon(Icons.business),
                      label: const Text('Assign Office'),
                      onPressed: () => _assignToOffice(request),
                    ),
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
            ],
          ),
        ),
      ),
    );
  }

  String _getOfficeName(String officeId) {
    final office = _offices.firstWhere(
      (office) => office.id == officeId,
      orElse: () => Office(
        id: officeId,
        name: 'Unknown Office',
        email: '',
        phoneNumber: '',
        address: '',
        createdAt: DateTime.now(),
      ),
    );
    return office.name;
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