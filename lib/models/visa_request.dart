enum VisaStatus {
  pending,
  documentsPending,
  paymentPending,
  paymentVerified,
  assigned,
  processing,
  completed,
  rejected,
}

class VisaRequest {
  final String id;
  final String applicantId;
  final String? adminId;
  final String? officeId;
  final String passportNumber;
  final VisaStatus status;
  final bool isPaid;
  final double paymentAmount;
  final String? paymentReference;
  final String? paymentScreenshotUrl;
  final DateTime paymentDate;
  final String? visaDocumentUrl;
  final List<String> documents;
  final DateTime createdAt;
  final DateTime? updatedAt;

  VisaRequest({
    required this.id,
    required this.applicantId,
    this.adminId,
    this.officeId,
    required this.passportNumber,
    required this.status,
    this.isPaid = false,
    required this.paymentAmount,
    this.paymentReference,
    this.paymentScreenshotUrl,
    required this.paymentDate,
    this.visaDocumentUrl,
    required this.documents,
    required this.createdAt,
    this.updatedAt,
  });

  VisaRequest copyWith({
    String? id,
    String? applicantId,
    String? adminId,
    String? officeId,
    String? passportNumber,
    VisaStatus? status,
    bool? isPaid,
    double? paymentAmount,
    String? paymentReference,
    String? paymentScreenshotUrl,
    DateTime? paymentDate,
    String? visaDocumentUrl,
    List<String>? documents,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return VisaRequest(
      id: id ?? this.id,
      applicantId: applicantId ?? this.applicantId,
      adminId: adminId ?? this.adminId,
      officeId: officeId ?? this.officeId,
      passportNumber: passportNumber ?? this.passportNumber,
      status: status ?? this.status,
      isPaid: isPaid ?? this.isPaid,
      paymentAmount: paymentAmount ?? this.paymentAmount,
      paymentReference: paymentReference ?? this.paymentReference,
      paymentScreenshotUrl: paymentScreenshotUrl ?? this.paymentScreenshotUrl,
      paymentDate: paymentDate ?? this.paymentDate,
      visaDocumentUrl: visaDocumentUrl ?? this.visaDocumentUrl,
      documents: documents ?? this.documents,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'applicantId': applicantId,
      'adminId': adminId,
      'officeId': officeId,
      'passportNumber': passportNumber,
      'status': status.toString().split('.').last,
      'isPaid': isPaid,
      'paymentAmount': paymentAmount,
      'paymentReference': paymentReference,
      'paymentScreenshotUrl': paymentScreenshotUrl,
      'paymentDate': paymentDate.millisecondsSinceEpoch,
      'visaDocumentUrl': visaDocumentUrl,
      'documents': documents,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt?.millisecondsSinceEpoch,
    };
  }

  factory VisaRequest.fromMap(Map<String, dynamic> map) {
    VisaStatus getStatus(String statusStr) {
      switch (statusStr) {
        case 'pending':
          return VisaStatus.pending;
        case 'documentsPending':
          return VisaStatus.documentsPending;
        case 'paymentPending':
          return VisaStatus.paymentPending;
        case 'paymentVerified':
          return VisaStatus.paymentVerified;
        case 'assigned':
          return VisaStatus.assigned;
        case 'processing':
          return VisaStatus.processing;
        case 'completed':
          return VisaStatus.completed;
        case 'rejected':
          return VisaStatus.rejected;
        default:
          return VisaStatus.pending;
      }
    }

    return VisaRequest(
      id: map['id'] ?? '',
      applicantId: map['applicantId'] ?? '',
      adminId: map['adminId'],
      officeId: map['officeId'],
      passportNumber: map['passportNumber'] ?? '',
      status: getStatus(map['status'] ?? 'pending'),
      isPaid: map['isPaid'] ?? false,
      paymentAmount: (map['paymentAmount'] ?? 0).toDouble(),
      paymentReference: map['paymentReference'],
      paymentScreenshotUrl: map['paymentScreenshotUrl'],
      paymentDate: DateTime.fromMillisecondsSinceEpoch(map['paymentDate'] ?? DateTime.now().millisecondsSinceEpoch),
      visaDocumentUrl: map['visaDocumentUrl'],
      documents: List<String>.from(map['documents'] ?? []),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
      updatedAt: map['updatedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['updatedAt'])
          : null,
    );
  }
}