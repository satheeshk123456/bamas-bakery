import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../models/branch.dart';
import '../services/api_client.dart';
import '../services/branch_service.dart';
import '../services/session.dart';

/// Branches.
///
/// Everyone with access to this screen can open and close a branch and edit
/// its phone / UPI id. Only the super admin (the developer) sees the "Add
/// branch" button, because adding a location changes licensing and the
/// profit split -- the backend enforces that too, this just avoids offering
/// a button that would return 403.
class BranchesScreen extends StatefulWidget {
  const BranchesScreen({super.key});

  @override
  State<BranchesScreen> createState() => _BranchesScreenState();
}

class _BranchesScreenState extends State<BranchesScreen> {
  late Future<List<Branch>> _future;

  @override
  void initState() {
    super.initState();
    _future = branchService.list(force: true);
  }

  void _reload() => setState(() => _future = branchService.list(force: true));

  Future<void> _toggleOpen(Branch b, bool value) async {
    try {
      await branchService.update(b.id, {'isOpen': value});
      _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update: ${e is ApiException ? e.message : e}')),
      );
    }
  }

  Future<void> _edit(Branch b) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _BranchForm(branch: b),
    );
    if (changed == true) _reload();
  }

  Future<void> _add() async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _BranchForm(),
    );
    if (changed == true) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Branches')),
      floatingActionButton: session.canManagePlatform
          ? FloatingActionButton.extended(
              onPressed: _add,
              icon: const Icon(Icons.add),
              label: const Text('Add branch'),
            )
          : null,
      body: FutureBuilder<List<Branch>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Could not load branches: ${snap.error}'));
          }
          final branches = snap.data ?? const <Branch>[];
          if (branches.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: Text(
                  'No branches yet. Add one so orders and menu items have '
                  'somewhere to belong.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
              itemCount: branches.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final b = branches[i];
                final bits = <String>[
                  if (b.contactPhone.isNotEmpty) b.contactPhone,
                  if (b.upiId.isNotEmpty) b.upiId else 'No UPI id set',
                  if (!b.isActive) 'HIDDEN FROM CUSTOMERS',
                ];
                return Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    title: Text(b.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (b.address.isNotEmpty) Text(b.address, style: const TextStyle(fontSize: 12.5)),
                        Text(
                          bits.join(' • '),
                          style: TextStyle(
                            fontSize: 12,
                            color: b.upiId.isEmpty ? AppBranding.danger : AppBranding.textMuted,
                          ),
                        ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          tooltip: 'Edit phone, address & UPI',
                          onPressed: () => _edit(b),
                        ),
                        Switch(
                          value: b.isOpen,
                          onChanged: (v) => _toggleOpen(b, v),
                        ),
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

class _BranchForm extends StatefulWidget {
  final Branch? branch;
  const _BranchForm({this.branch});

  @override
  State<_BranchForm> createState() => _BranchFormState();
}

class _BranchFormState extends State<_BranchForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _address;
  late final TextEditingController _phone;
  late final TextEditingController _upi;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final b = widget.branch;
    _name = TextEditingController(text: b?.name ?? '');
    _address = TextEditingController(text: b?.address ?? '');
    _phone = TextEditingController(text: b?.contactPhone ?? '');
    _upi = TextEditingController(text: b?.upiId ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _phone.dispose();
    _upi.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final body = {
        'name': _name.text.trim(),
        'address': _address.text.trim(),
        'contactPhone': _phone.text.trim(),
        'upiId': _upi.text.trim(),
      };
      if (widget.branch == null) {
        await branchService.create(
          name: body['name']!,
          address: body['address']!,
          contactPhone: body['contactPhone']!,
          upiId: body['upiId']!,
        );
      } else {
        await branchService.update(widget.branch!.id, body);
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
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.branch == null ? 'Add branch' : 'Edit ${widget.branch!.name}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Branch name', hintText: 'e.g. Gandhipuram'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _address,
              decoration: const InputDecoration(labelText: 'Address'),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'WhatsApp / contact number',
                helperText: "This branch's orders are sent to this number",
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _upi,
              decoration: const InputDecoration(
                labelText: 'UPI ID',
                helperText: "Customers pay THIS branch here. Leave it blank and they can't pay.",
              ),
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
                  : Text(widget.branch == null ? 'Add branch' : 'Save changes'),
            ),
          ],
        ),
      ),
    );
  }
}
