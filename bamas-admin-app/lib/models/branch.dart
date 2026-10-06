/// One shop location, as the admin app sees it.
class Branch {
  final String id;
  final String name;
  final String address;
  final String contactPhone;
  final String upiId;
  final String gpayQrUrl;
  final bool isOpen;
  final bool isActive;
  final int sortOrder;

  const Branch({
    required this.id,
    required this.name,
    this.address = '',
    this.contactPhone = '',
    this.upiId = '',
    this.gpayQrUrl = '',
    this.isOpen = true,
    this.isActive = true,
    this.sortOrder = 0,
  });

  factory Branch.fromJson(Map<String, dynamic> json) => Branch(
        id: (json['id'] ?? '').toString(),
        name: json['name'] ?? '',
        address: json['address'] ?? '',
        contactPhone: json['contactPhone'] ?? '',
        upiId: json['upiId'] ?? '',
        gpayQrUrl: json['gpayQrUrl'] ?? '',
        isOpen: json['isOpen'] ?? true,
        isActive: json['isActive'] ?? true,
        sortOrder: (json['sortOrder'] ?? 0) as int,
      );
}

/// A staff login. The password hash is never sent by the backend, so there
/// is nothing sensitive here.
class AdminAccount {
  final String id;
  final String username;
  final String name;
  final String role;
  final String? branchId;
  final bool isActive;

  /// Who created this login. Blank for accounts that predate the change,
  /// and "server" for the first developer account, which has to be made
  /// from the command line because creating one needs an existing login.
  final String createdByName;

  const AdminAccount({
    required this.id,
    required this.username,
    this.name = '',
    this.role = '',
    this.branchId,
    this.isActive = true,
    this.createdByName = '',
  });

  factory AdminAccount.fromJson(Map<String, dynamic> json) => AdminAccount(
        id: (json['id'] ?? '').toString(),
        username: json['username'] ?? '',
        name: json['name'] ?? '',
        role: json['role'] ?? '',
        branchId: json['branchId'] as String?,
        isActive: json['isActive'] ?? true,
        createdByName: json['createdByName'] ?? '',
      );
}
