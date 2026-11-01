import 'package:flutter/foundation.dart';

@immutable
class StoreEditRequest {
  final String id;
  final String sellerId;
  final String applicantEmail;
  final String currentBusinessName;
  final String proposedBusinessName;
  final String currentMarketHub;
  final String proposedMarketHub;
  final String? currentStallLocation;
  final String? proposedStallLocation;
  final String? currentPhone;
  final String proposedPhone;
  final String currentSellerChannel;
  final String proposedSellerChannel;
  final String status; // 'pending', 'approved', 'rejected'
  final DateTime submittedAt;
  final DateTime? reviewedAt;
  final String? reviewedBy;
  final String? rejectionReason;

  const StoreEditRequest({
    required this.id,
    required this.sellerId,
    required this.applicantEmail,
    required this.currentBusinessName,
    required this.proposedBusinessName,
    required this.currentMarketHub,
    required this.proposedMarketHub,
    this.currentStallLocation,
    this.proposedStallLocation,
    this.currentPhone,
    required this.proposedPhone,
    required this.currentSellerChannel,
    required this.proposedSellerChannel,
    this.status = 'pending',
    required this.submittedAt,
    this.reviewedAt,
    this.reviewedBy,
    this.rejectionReason,
  });

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';

  StoreEditRequest copyWith({
    String? id,
    String? sellerId,
    String? applicantEmail,
    String? currentBusinessName,
    String? proposedBusinessName,
    String? currentMarketHub,
    String? proposedMarketHub,
    String? currentStallLocation,
    String? proposedStallLocation,
    String? currentPhone,
    String? proposedPhone,
    String? currentSellerChannel,
    String? proposedSellerChannel,
    String? status,
    DateTime? submittedAt,
    DateTime? reviewedAt,
    String? reviewedBy,
    String? rejectionReason,
  }) {
    return StoreEditRequest(
      id: id ?? this.id,
      sellerId: sellerId ?? this.sellerId,
      applicantEmail: applicantEmail ?? this.applicantEmail,
      currentBusinessName: currentBusinessName ?? this.currentBusinessName,
      proposedBusinessName: proposedBusinessName ?? this.proposedBusinessName,
      currentMarketHub: currentMarketHub ?? this.currentMarketHub,
      proposedMarketHub: proposedMarketHub ?? this.proposedMarketHub,
      currentStallLocation: currentStallLocation ?? this.currentStallLocation,
      proposedStallLocation:
          proposedStallLocation ?? this.proposedStallLocation,
      currentPhone: currentPhone ?? this.currentPhone,
      proposedPhone: proposedPhone ?? this.proposedPhone,
      currentSellerChannel: currentSellerChannel ?? this.currentSellerChannel,
      proposedSellerChannel:
          proposedSellerChannel ?? this.proposedSellerChannel,
      status: status ?? this.status,
      submittedAt: submittedAt ?? this.submittedAt,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      rejectionReason: rejectionReason ?? this.rejectionReason,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'seller_id': sellerId,
      'applicant_email': applicantEmail,
      'current_business_name': currentBusinessName,
      'proposed_business_name': proposedBusinessName,
      'current_market_hub': currentMarketHub,
      'proposed_market_hub': proposedMarketHub,
      'current_stall_location': currentStallLocation,
      'proposed_stall_location': proposedStallLocation,
      'current_phone': currentPhone,
      'proposed_phone': proposedPhone,
      'current_seller_channel': currentSellerChannel,
      'proposed_seller_channel': proposedSellerChannel,
      'status': status,
      'submitted_at': submittedAt.toIso8601String(),
      'reviewed_at': reviewedAt?.toIso8601String(),
      'reviewed_by': reviewedBy,
      'rejection_reason': rejectionReason,
    };
  }

  factory StoreEditRequest.fromJson(Map<String, dynamic> json) {
    return StoreEditRequest(
      id: (json['id'] ?? '') as String,
      sellerId: (json['seller_id'] ?? json['sellerId'] ?? '') as String,
      applicantEmail:
          (json['applicant_email'] ?? json['applicantEmail'] ?? '') as String,
      currentBusinessName: (json['current_business_name'] ??
          json['currentBusinessName'] ??
          '') as String,
      proposedBusinessName: (json['proposed_business_name'] ??
          json['proposedBusinessName'] ??
          '') as String,
      currentMarketHub: (json['current_market_hub'] ??
          json['currentMarketHub'] ??
          '') as String,
      proposedMarketHub: (json['proposed_market_hub'] ??
          json['proposedMarketHub'] ??
          '') as String,
      currentStallLocation: (json['current_stall_location'] ??
          json['currentStallLocation']) as String?,
      proposedStallLocation: (json['proposed_stall_location'] ??
          json['proposedStallLocation']) as String?,
      currentPhone:
          (json['current_phone'] ?? json['currentPhone']) as String?,
      proposedPhone:
          (json['proposed_phone'] ?? json['proposedPhone'] ?? '') as String,
      currentSellerChannel: (json['current_seller_channel'] ??
          json['currentSellerChannel'] ??
          'Local Market') as String,
      proposedSellerChannel: (json['proposed_seller_channel'] ??
          json['proposedSellerChannel'] ??
          'Local Market') as String,
      status: (json['status'] ?? 'pending') as String,
      submittedAt: json['submitted_at'] != null
          ? DateTime.parse(json['submitted_at'] as String)
          : (json['submittedAt'] != null
              ? DateTime.parse(json['submittedAt'] as String)
              : DateTime.now()),
      reviewedAt: json['reviewed_at'] != null
          ? DateTime.parse(json['reviewed_at'] as String)
          : (json['reviewedAt'] != null
              ? DateTime.parse(json['reviewedAt'] as String)
              : null),
      reviewedBy: (json['reviewed_by'] ?? json['reviewedBy']) as String?,
      rejectionReason:
          (json['rejection_reason'] ?? json['rejectionReason']) as String?,
    );
  }
}
