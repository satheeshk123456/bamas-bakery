import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Who is logged into this admin phone, and what they are allowed to do.
///
/// IMPORTANT: none of this is a security control. The backend re-reads the
/// account on every single request and refuses anything out of scope -- a
/// branch manager cannot read another branch's orders even if this app were
/// rebuilt with the checks removed. What this class is for is showing the
/// right screens, so a manager isn't offered buttons that would only ever
/// return 403.
class Session {
  Session._();
  static final Session instance = Session._();

  static const roleSuperAdmin = 'super_admin';
  static const roleOwner = 'owner';
  static const roleBranchManager = 'branch_manager';

  static const _kRole = 'bamas_admin_role';
  static const _kBranchId = 'bamas_admin_branch_id';
  static const _kName = 'bamas_admin_name';

  /// Bumped whenever the signed-in account changes, so screens rebuild.
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  String role = '';
  String? branchId;
  String name = '';

  /// The .env bootstrap login and any account created before roles existed
  /// report an empty role. Treating that as super_admin keeps the shop
  /// owner's existing login working exactly as it did before the upgrade --
  /// full access -- instead of silently locking them out of their own app.
  bool get isSuperAdmin => role == roleSuperAdmin || role.isEmpty;
  bool get isOwner => role == roleOwner;
  bool get isBranchManager => role == roleBranchManager;

  /// Sees every branch: the developer and the shop owner.
  bool get seesAllBranches => isSuperAdmin || isOwner;

  /// Can create BRANCHES, and can create admin/developer logins. Developer
  /// only, because both change what the platform is owed.
  bool get canManagePlatform => isSuperAdmin;

  /// Can open the Staff logins screen. The developer manages everyone; the
  /// admin manages branch managers. A branch manager gets nothing -- the
  /// backend returns 403 for them regardless.
  bool get canManageStaff => seesAllBranches;

  Future<void> save({required String role, String? branchId, String name = ''}) async {
    this.role = role;
    this.branchId = (branchId != null && branchId.isNotEmpty) ? branchId : null;
    this.name = name;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kRole, role);
    await prefs.setString(_kName, name);
    if (this.branchId == null) {
      await prefs.remove(_kBranchId);
    } else {
      await prefs.setString(_kBranchId, this.branchId!);
    }
    revision.value++;
  }

  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    role = prefs.getString(_kRole) ?? '';
    branchId = prefs.getString(_kBranchId);
    name = prefs.getString(_kName) ?? '';
    revision.value++;
  }

  Future<void> clear() async {
    role = '';
    branchId = null;
    name = '';
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kRole);
    await prefs.remove(_kBranchId);
    await prefs.remove(_kName);
    revision.value++;
  }
}

final session = Session.instance;
