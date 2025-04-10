import 'package:flutter/material.dart';
import 'package:visa_mediation_app/models/visa_request.dart';
import 'package:visa_mediation_app/services/auth_service.dart';
import 'package:visa_mediation_app/services/database_service.dart';

class ApplicantDashboard extends StatefulWidget {
  final String userId;

  const ApplicantDashboard({Key? key, required this.userId}) : super(key: key);

  @override
  _ApplicantDashboardState createState() => _ApplicantDashboardState();
}

class _ApplicantDashboardState extends State<ApplicantDashboard> {
  final AuthService _authService = AuthService();
  final DatabaseService _databaseService = DatabaseService();

  List<VisaRequest> _visaRequests = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadVisaRequests();
  }

  Future<void> _loadVisaRequests() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      final requests = await _databaseService.getApplicantVisaRequests(widget.userId);

      setState(() {
        _visaRequests = requests;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load visa requests: $e';
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

  Future<void> _createNewVisaRequest() async {
    // Navigate to visa request creation form
    // For now, we'll show a simple dialog to get passport number
    final passport = await _showPassportDialog();
    
    if (passport != null && passport.isNotEmpty) {
      try {
        setState(() {
          _isLoading = true;
        });
        
        await _databaseService.createVisaRequest(
          applicantId: widget.userId,
          passportNumber: passport,
        );
        
        // Reload the list
        await _loadVisaRequests();
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Visa request created successfully')),
        );
      } catch (e) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to create visa request: $e';
        });
      }
    }
  }

  Future<String?> _showPassportDialog() async {
    final controller = TextEditingController();
    
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Visa Request'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Passport Number',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(context, controller.text.trim());
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Visa Applicant Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
          ),
        ],
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
                          onPressed: _loadVisaRequests,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : _buildContent(),
      floatingActionButton: FloatingActionButton(
        onPressed: _createNewVisaRequest,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildContent() {
    if (_visaRequests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.flight_takeoff,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            const Text(
              'No visa requests yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap the + button to create a new visa request',
              style: TextStyle(
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _createNewVisaRequest,
              child: const Text('Create New Request'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadVisaRequests,
      child: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: _visaRequests.length,
        itemBuilder: (context, index) {
          final request = _visaRequests[index];
          return _buildVisaRequestCard(request);
        },
      ),
    );
  }

  Widget _buildVisaRequestCard(VisaRequest request) {
    Color statusColor;
    IconData statusIcon;

    switch (request.status) {
      case VisaStatus.pending:
      case VisaStatus.documentsPending:
      case VisaStatus.paymentPending:
        statusColor = Colors.orange;
        statusIcon = Icons.hourglass_empty;
        break;
      case VisaStatus.paymentVerified:
      case VisaStatus.assigned:
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
                    'Visa Request #${request.id.substring(0, 8)}',
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
                      ),
                    ),
                    backgroundColor: statusColor.withOpacity(0.1),
                  ),
                ],
              ),
              const Divider(),
              _buildInfoRow('Passport:', request.passportNumber),
              _buildInfoRow('Created:', _formatDate(request.createdAt)),
              _buildInfoRow(
                'Payment:',
                request.isPaid ? 'Paid (EGP ${request.paymentAmount})' : 'Not Paid',
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.chat),
                    label: const Text('Open Chat'),
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