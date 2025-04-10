class Office {
  final String id;
  final String name;
  final String email;
  final String phoneNumber;
  final String address;
  final String logoUrl;
  final int maxActiveApplications;
  final int currentActiveApplications;
  final bool isVerified;
  final DateTime createdAt;
  final DateTime? lastActiveAt;

  Office({
    required this.id,
    required this.name,
    required this.email,
    required this.phoneNumber,
    required this.address,
    this.logoUrl = '',
    this.maxActiveApplications = 5,
    this.currentActiveApplications = 0,
    this.isVerified = false,
    required this.createdAt,
    this.lastActiveAt,
  });

  bool canAcceptApplication() {
    return currentActiveApplications < maxActiveApplications;
  }

  Office copyWith({
    String? id,
    String? name,
    String? email,
    String? phoneNumber,
    String? address,
    String? logoUrl,
    int? maxActiveApplications,
    int? currentActiveApplications,
    bool? isVerified,
    DateTime? createdAt,
    DateTime? lastActiveAt,
  }) {
    return Office(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      address: address ?? this.address,
      logoUrl: logoUrl ?? this.logoUrl,
      maxActiveApplications: maxActiveApplications ?? this.maxActiveApplications,
      currentActiveApplications: currentActiveApplications ?? this.currentActiveApplications,
      isVerified: isVerified ?? this.isVerified,
      createdAt: createdAt ?? this.createdAt,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phoneNumber': phoneNumber,
      'address': address,
      'logoUrl': logoUrl,
      'maxActiveApplications': maxActiveApplications,
      'currentActiveApplications': currentActiveApplications,
      'isVerified': isVerified,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'lastActiveAt': lastActiveAt?.millisecondsSinceEpoch,
    };
  }

  factory Office.fromMap(Map<String, dynamic> map) {
    return Office(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      address: map['address'] ?? '',
      logoUrl: map['logoUrl'] ?? '',
      maxActiveApplications: map['maxActiveApplications'] ?? 5,
      currentActiveApplications: map['currentActiveApplications'] ?? 0,
      isVerified: map['isVerified'] ?? false,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
      lastActiveAt: map['lastActiveAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['lastActiveAt'])
          : null,
    );
  }
}