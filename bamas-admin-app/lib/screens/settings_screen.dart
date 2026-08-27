import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../app_theme.dart';
import '../models/shop_settings.dart';
import '../services/shop_service.dart';

/// Everything about the shop that used to only be changeable by editing
/// seed.py and re-running it: the WhatsApp contact number, address, UPI
/// ID, hero banner text, the weekend-offer banner, and the shop's own
/// photos. Saving here updates shopSettings/main directly, so the
/// customer app picks up the change immediately -- no reinstall, no
/// reseed, no redeploy.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  AdminShopSettings? _settings;
  bool _loading = true;
  bool _saving = false;
  String? _uploadingField;
  String? _error;

  final _shopNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _upiCtrl = TextEditingController();
  final _heroHeadlineCtrl = TextEditingController();
  final _heroTaglineCtrl = TextEditingController();
  final _weekendTextCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _shopNameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _upiCtrl.dispose();
    _heroHeadlineCtrl.dispose();
    _heroTaglineCtrl.dispose();
    _weekendTextCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final s = await shopService.getSettings();
      _shopNameCtrl.text = s.shopName;
      _phoneCtrl.text = s.contactPhone;
      _addressCtrl.text = s.address;
      _upiCtrl.text = s.upiId;
      _heroHeadlineCtrl.text = s.heroHeadline;
      _heroTaglineCtrl.text = s.heroTagline;
      _weekendTextCtrl.text = s.weekendOfferText;
      setState(() => _settings = s);
    } catch (e) {
      setState(() => _error = 'Could not load settings: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_settings == null) return;
    setState(() => _saving = true);
    try {
      final updated = _settings!.copyWith(
        shopName: _shopNameCtrl.text.trim(),
        contactPhone: _phoneCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        upiId: _upiCtrl.text.trim(),
        heroHeadline: _heroHeadlineCtrl.text.trim(),
        heroTagline: _heroTaglineCtrl.text.trim(),
        weekendOfferText: _weekendTextCtrl.text.trim(),
      );
      final saved = await shopService.updateSettings(updated);
      if (!mounted) return;
      setState(() => _settings = saved);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings saved.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickAndUploadImage(String field, {int maxWidth = 1000}) async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: maxWidth.toDouble(),
      imageQuality: 70,
    );
    if (picked == null || _settings == null) return;
    setState(() => _uploadingField = field);
    try {
      final url = await shopService.uploadImage(field, File(picked.path));
      setState(() => _settings = _applyImage(_settings!, field, url));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Photo updated.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not upload photo: $e')));
    } finally {
      if (mounted) setState(() => _uploadingField = null);
    }
  }

  AdminShopSettings _applyImage(AdminShopSettings s, String field, String url) {
    switch (field) {
      case 'logoUrl':
        return s.copyWith(logoUrl: url);
      case 'heroImageUrl':
        return s.copyWith(heroImageUrl: url);
      case 'gpayQrUrl':
        return s.copyWith(gpayQrUrl: url);
      case 'weekendOfferImageUrl':
        return s.copyWith(weekendOfferImageUrl: url);
      default:
        return s;
    }
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium),
      );

  Widget _imagePreview(String source) {
    if (source.isEmpty) {
      return const Center(child: Icon(Icons.image_outlined, color: AppBranding.textMuted, size: 30));
    }
    if (source.startsWith('data:')) {
      try {
        final bytes = base64Decode(source.substring(source.indexOf(',') + 1));
        return Image.memory(bytes, fit: BoxFit.cover);
      } catch (_) {
        return const Center(child: Icon(Icons.broken_image_outlined, color: AppBranding.textMuted));
      }
    }
    return Image.network(
      source,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image_outlined, color: AppBranding.textMuted)),
    );
  }

  Widget _imageTile({
    required String label,
    required String source,
    required String field,
    int maxWidth = 1000,
  }) {
    final busy = _uploadingField == field;
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 64,
            height: 64,
            color: Colors.grey.shade200,
            child: busy ? const Center(child: CircularProgressIndicator(strokeWidth: 2)) : _imagePreview(source),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              TextButton(
                onPressed: busy ? null : () => _pickAndUploadImage(field, maxWidth: maxWidth),
                child: Text(source.isEmpty ? 'Add photo' : 'Change photo'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!)))
              : SafeArea(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Shop is open'),
                        subtitle: const Text('Turn off to pause new orders'),
                        value: _settings!.isOpen,
                        onChanged: (v) => setState(() => _settings = _settings!.copyWith(isOpen: v)),
                      ),
                      _sectionTitle('Contact & address'),
                      TextField(
                        controller: _shopNameCtrl,
                        decoration: const InputDecoration(labelText: 'Shop name'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'WhatsApp / contact number',
                          helperText: "Customers' WhatsApp order notification is sent to this number",
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _addressCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(labelText: 'Address'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _upiCtrl,
                        decoration: const InputDecoration(labelText: 'UPI ID (shown next to the payment QR)'),
                      ),
                      _sectionTitle('Home screen banner'),
                      TextField(
                        controller: _heroHeadlineCtrl,
                        decoration: const InputDecoration(labelText: 'Headline'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _heroTaglineCtrl,
                        decoration: const InputDecoration(labelText: 'Tagline'),
                      ),
                      const SizedBox(height: 16),
                      _imageTile(label: 'Hero photo', source: _settings!.heroImageUrl, field: 'heroImageUrl'),
                      const SizedBox(height: 16),
                      _imageTile(label: 'Shop logo', source: _settings!.logoUrl, field: 'logoUrl', maxWidth: 600),
                      _sectionTitle('Payment QR'),
                      _imageTile(label: 'GPay / UPI QR code', source: _settings!.gpayQrUrl, field: 'gpayQrUrl', maxWidth: 800),
                      _sectionTitle('Weekend offer banner'),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Show weekend offer banner'),
                        value: _settings!.weekendOfferEnabled,
                        onChanged: (v) => setState(() => _settings = _settings!.copyWith(weekendOfferEnabled: v)),
                      ),
                      TextField(
                        controller: _weekendTextCtrl,
                        decoration: const InputDecoration(labelText: 'Offer text'),
                      ),
                      const SizedBox(height: 16),
                      _imageTile(
                        label: 'Weekend offer photo',
                        source: _settings!.weekendOfferImageUrl,
                        field: 'weekendOfferImageUrl',
                        maxWidth: 1000,
                      ),
                      const SizedBox(height: 28),
                      ElevatedButton(
                        onPressed: _saving ? null : _save,
                        child: _saving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Save changes'),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }
}
