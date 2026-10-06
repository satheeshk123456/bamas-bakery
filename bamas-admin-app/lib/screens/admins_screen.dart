import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../models/branch.dart';
import '../services/admin_account_service.dart';
import '../services/api_client.dart';
import '../services/branch_service.dart';
import '../services/session.dart';

/// Staff logins.
///
/// The DEVELOPER manages every account -- other developers, admins, and
/// branch managers -- and sees who created each one. The ADMIN manages
/// branch managers only: they cannot create an admin, and cannot promote a
/// manager into one. Both rules are enforced by the backend; the UI below
/// just avoids offering buttons that would return 403.
///
/// This is also the ONLY password reset in the whole system -- there is no
/// "forgot password" anywhere, by design -- so a locked-out manager is
/// fixed from here.
class AdminsScreen extends StatefulWidget {
  const AdminsScreen({super.key});

  @override
  State<AdminsScreen> createState() => _AdminsScreenState();
}

class _AdminsScreenState extends State<AdminsScreen> {
  late Future<List<AdminAccount>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<AdminAccount>> _load() async {
    // Branches first: every row needs to show which branch a manager runs.
    await branchService.list(force: true);
    return adminAccountService.list();
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _openForm({AdminAccount? account}) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AdminForm(account: account),
    );
    if (changed == true) _reload();
  }

  Future<void> _toggleActive(AdminAccount a, bool value) async {
    try {
      await adminAccountService.update(a.id, {'isActive': value});
      _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(value
              ? '${a.username} can log in again.'
              : '${a.username} is locked out immediately, even on a phone that is already logged in.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update: ${e is ApiException ? e.message : e}')),
      );
    }
  }

  String _describe(AdminAccount a) {
    switch (a.role) {
      case Session.roleSuperAdmin:
        return 'Developer — everything';
      case Session.roleOwner:
        return 'Owner — every branch';
      case Session.roleBranchManager:
        final b = branchService.byId(a.branchId);
        return 'Manager — ${b?.name ?? 'branch missing!'}';
      default:
        return a.role;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Staff logins')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.person_add_alt),
        label: const Text('Add login'),
      ),
      body: FutureBuilder<List<AdminAccount>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Could not load staff: ${snap.error}'));
          }
          final accounts = snap.data ?? const <AdminAccount>[];
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
              itemCount: accounts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final a = accounts[i];
                return Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    title: Text(
                      a.name.isEmpty ? a.username : a.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(a.username, style: const TextStyle(fontSize: 12.5)),
                        Text(_describe(a),
                            style: const TextStyle(fontSize: 12, color: AppBranding.textMuted)),
                        // Only the developer sees this: the admin's own list
                        // is all managers, so "created by" adds nothing there.
                        if (session.canManagePlatform && a.createdByName.isNotEmpty)
                          Text('Created by ${a.createdByName}',
                              style: const TextStyle(fontSize: 11, color: AppBranding.textMuted)),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          tooltip: 'Change role, branch or password',
                          onPressed: () => _openForm(account: a),
                        ),
                        Switch(value: a.isActive, onChanged: (v) => _toggleActive(a, v)),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _AdminForm extends StatefulWidget {
  final AdminAccount? account;
  const _AdminForm({this.account});

  @override
  State<_AdminForm> createState() => _AdminFormState();
}

class _AdminFormState extends State<_AdminForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _username;
  late final TextEditingController _name;
  final _password = TextEditingController();
  late String _role;
  String? _branchId;
  bool _saving = false;
  String? _error;

  bool get _isNew => widget.account == null;

  @override
  void initState() {
    super.initState();
    final a = widget.account;
    _username = TextEditingController(text: a?.username ?? '');
    _name = TextEditingController(text: a?.name ?? '');
    _role = a?.role.isNotEmpty == true ? a!.role : Session.roleBranchManager;
    _branchId = a?.branchId;
  }

  @override
  void dispose() {
    _username.dispose();
    _name.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_role == Session.roleBranchManager && (_branchId == null || _branchId!.isEmpty)) {
      setState(() => _error = 'Choose which branch this manager runs.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (_isNew) {
        await adminAccountService.create(
          username: _username.text.trim(),
          password: _password.text,
          name: _name.text.trim(),
          role: _role,
          branchId: _role == Session.roleBranchManager ? _branchId : null,
        );
      } else {
        await adminAccountService.update(widget.account!.id, {
          'name': _name.text.trim(),
          'role': _role,
          if (_role == Session.roleBranchManager) 'branchId': _branchId,
          if (_password.text.isNotEmpty) 'password': _password.text,
        });
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      setState(() => _error = e is ApiException ? e.message : 'Could not save: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final branches = branchService.cached;
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(_isNew ? 'Add login' : 'Edit ${widget.account!.username}',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 14),
              TextFormField(
                controller: _username,
                // The username IS the identity on the backend; changing it
                // would orphan the account, so it is fixed after creation.
                enabled: _isNew,
                decoration: const InputDecoration(labelText: 'Username', hintText: 'e.g. gandhipuram'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a username' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Display name'),
              ),
              const SizedBox(height: 12),
              if (session.canManagePlatform)
                DropdownButtonFormField<String>(
                  initialValue: _role,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: const [
                    DropdownMenuItem(value: Session.roleBranchManager, child: Text('Branch manager — one branch')),
                    DropdownMenuItem(value: Session.roleOwner, child: Text('Admin — every branch')),
                    DropdownMenuItem(value: Session.roleSuperAdmin, child: Text('Developer — everything')),
                  ],
                  onChanged: (v) => setState(() {
                    _role = v ?? Session.roleBranchManager;
                    if (_role != Session.roleBranchManager) _branchId = null;
                  }),
                )
              else
                // An admin only ever creates branch managers, so there is no
                // choice to offer -- showing a dropdown with one option (or
                // options that 403) would just be confusing.
                const InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Role',
                    helperText: 'Only the developer can create admin logins',
                  ),
                  child: Text('Branch manager — one branch'),
                ),
              if (_role == Session.roleBranchManager) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: branches.any((b) => b.id == _branchId) ? _branchId : null,
                  decoration: const InputDecoration(labelText: 'Branch'),
                  items: [
                    for (final b in branches)
                      DropdownMenuItem(value: b.id, child: Text(b.name)),
                  ],
                  onChanged: (v) => setState(() => _branchId = v),
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: _password,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: _isNew ? 'Password' : 'New password (leave blank to keep)',
                  helperText: 'At least 8 characters',
                ),
                validator: (v) {
                  if (_isNew && (v == null || v.length < 8)) return 'At least 8 characters';
                  if (!_isNew && v != null && v.isNotEmpty && v.length < 8) return 'At least 8 characters';
                  return null;
                },
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: AppBranding.danger)),
              ],
              const SizedBox(height: 18),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 18, width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(_isNew ? 'Create login' : 'Save changes'),
              ),
              const SizedBox(height: 8),
              const Text(
                'Write the password down and give it to them directly — it is '
                'stored hashed and cannot be read back later.',
                style: TextStyle(fontSize: 11.5, color: AppBranding.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
