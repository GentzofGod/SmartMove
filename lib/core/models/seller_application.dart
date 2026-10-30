enum SellerApplicationStatus {
  none,
  pending,
  approved,
  rejected;

  String get label {
    switch (this) {
      case SellerApplicationStatus.none:
        return 'Not Applied';
      case SellerApplicationStatus.pending:
        return 'Pending Approval';
      case SellerApplicationStatus.approved:
        return 'Approved & Active';
      case SellerApplicationStatus.rejected:
        return 'Application Rejected';
    }
  }
}

class SellerApplication {
  final String id;
  final String userId;
  final String applicantName;
  final String applicantEmail;
  final String businessName;
  final String marketHub;
  final String sellerChannel;
  final String? stallLocation;
  final String phone;
  final SellerApplicationStatus status;
  final DateTime submittedAt;
  final DateTime? reviewedAt;
  final String? rejectionReason;

  const SellerApplication({
    required this.id,
    required this.userId,
    required this.applicantName,
    required this.applicantEmail,
    required this.businessName,
    required this.marketHub,
    required this.sellerChannel,
    this.stallLocation,
    required this.phone,
    this.status = SellerApplicationStatus.pending,
    required this.submittedAt,
    this.reviewedAt,
    this.rejectionReason,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'applicantName': applicantName,
        'applicantEmail': applicantEmail,
        'businessName': businessName,
        'marketHub': marketHub,
        'sellerChannel': sellerChannel,
        'stallLocation': stallLocation,
        'phone': phone,
        'status': status.name,
        'submittedAt': submittedAt.toIso8601String(),
        'reviewedAt': reviewedAt?.toIso8601String(),
        'rejectionReason': rejectionReason,
      };

  Map<String, dynamic> toDbMap() => {
        'user_id': userId,
        'applicant_name': applicantName,
        'applicant_email': applicantEmail,
        'business_name': businessName,
        'market_hub': marketHub,
        'seller_channel': sellerChannel,
        'stall_location': stallLocation,
        'phone': phone,
        'status': status.name,
        'submitted_at': submittedAt.toIso8601String(),
        'reviewed_at': reviewedAt?.toIso8601String(),
        'rejection_reason': rejectionReason,
      };

  factory SellerApplication.fromJson(Map<String, dynamic> json) =>
      SellerApplication(
        id: json['id'] as String? ??
            'app-${DateTime.now().millisecondsSinceEpoch}',
        userId: (json['userId'] ?? json['user_id']) as String? ?? '',
        applicantName:
            (json['applicantName'] ?? json['applicant_name']) as String? ?? '',
        applicantEmail:
            (json['applicantEmail'] ?? json['applicant_email']) as String? ?? '',
        businessName:
            (json['businessName'] ?? json['business_name']) as String? ?? '',
        marketHub:
            (json['marketHub'] ?? json['market_hub']) as String? ?? 'Bodija Market',
        sellerChannel:
            (json['sellerChannel'] ?? json['seller_channel']) as String? ?? 'Local Market',
        stallLocation:
            (json['stallLocation'] ?? json['stall_location']) as String?,
        phone: json['phone'] as String? ?? '',
        status: SellerApplicationStatus.values.firstWhere(
          (s) => s.name == json['status'],
          orElse: () => SellerApplicationStatus.pending,
        ),
        submittedAt: json['submittedAt'] != null || json['submitted_at'] != null
            ? DateTime.tryParse(
                    (json['submittedAt'] ?? json['submitted_at']).toString()) ??
                DateTime.now()
            : DateTime.now(),
        reviewedAt: json['reviewedAt'] != null || json['reviewed_at'] != null
            ? DateTime.tryParse(
                (json['reviewedAt'] ?? json['reviewed_at']).toString())
            : null,
        rejectionReason:
            (json['rejectionReason'] ?? json['rejection_reason']) as String?,
      );

  SellerApplication copyWith({
    String? id,
    String? userId,
    String? applicantName,
    String? applicantEmail,
    String? businessName,
    String? marketHub,
    String? sellerChannel,
    String? stallLocation,
    String? phone,
    SellerApplicationStatus? status,
    DateTime? submittedAt,
    DateTime? reviewedAt,
    String? rejectionReason,
  }) {
    return SellerApplication(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      applicantName: applicantName ?? this.applicantName,
      applicantEmail: applicantEmail ?? this.applicantEmail,
      businessName: businessName ?? this.businessName,
      marketHub: marketHub ?? this.marketHub,
      sellerChannel: sellerChannel ?? this.sellerChannel,
      stallLocation: stallLocation ?? this.stallLocation,
      phone: phone ?? this.phone,
      status: status ?? this.status,
      submittedAt: submittedAt ?? this.submittedAt,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      rejectionReason: rejectionReason ?? this.rejectionReason,
    );
  }
}
