import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app_theme.dart';
import '../models/shop_settings.dart';
import '../services/firestore_service.dart';

/// Lets a customer send a question to the shop (bulk orders, catering,
/// timings, complaints). Messages land in the admin panel's Enquiries
/// inbox. Also surfaces the shop's phone number for a direct call.
class EnquiryScreen extends StatefulWidget {
  final bool embedded;
  const EnquiryScreen({super.key, this.embedded = false});

  @override
  State<EnquiryScreen> createState() => _EnquiryScreenState();
}

class _EnquiryScreenState extends State<EnquiryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  final _firestore = FirestoreService();
  bool _sending = false;
  bool _sent = false;

  @override
  void initState() {
    super.initState();
    _prefill();
  }

  Future<void> _prefill() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    _nameCtrl.text = prefs.getString('customerName') ?? '';
    _phoneCtrl.text = prefs.getString('customerPhone') ?? '';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _sending = true);
    try {
      await _firestore.submitEnquiry(
        name: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        message: _messageCtrl.text.trim(),
      );
      if (!mounted) return;
      setState(() => _sent = true);
      _messageCtrl.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not send: $e')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          StreamBuilder<ShopSettings>(
            stream: _firestore.shopSettingsStream(),
            builder: (context, snap) {
              final phone = snap.data?.contactPhone ?? '';
              final address = snap.data?.address ?? '';
              if (phone.isEmpty && address.isEmpty) {
                return const SizedBox.shrink();
              }
              return Container(
                margin: const EdgeInsets.only(bottom: 18),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppBranding.primary.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Reach us directly',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    if (phone.isNotEmpty)
                      InkWell(
                        onTap: () async {
                          final uri = Uri(
                            scheme: 'tel',
                            path: phone.replaceAll(RegExp(r'[^0-9+]'), ''),
                          );
                          if (await canLaunchUrl(uri)) await launchUrl(uri);
                        },
                        child: Row(
                          children: [
                            const Icon(Icons.call,
                                size: 17, color: AppBranding.primary),
                            const SizedBox(width: 8),
                            Text(phone,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: AppBranding.primary)),
                          ],
                        ),
                      ),
                    if (address.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.location_on_outlined,
                              size: 17, color: AppBranding.textMuted),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(address,
                                style: const TextStyle(fontSize: 13)),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              );
            },
          ),

          if (_sent)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppBranding.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle, color: AppBranding.success, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                        "Thanks! We've got your message and will get back to you."),
                  ),
                ],
              ),
            ),

          Text('Send us a message',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          TextFormField(
            controller: _nameCtrl,
            decoration: const InputDecoration(labelText: 'Your name'),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Enter your name' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Phone number'),
            validator: (v) {
              final digits = (v ?? '').replaceAll(RegExp(r'[^0-9]'), '');
              if (digits.length < 10) return 'Enter a valid phone number';
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _messageCtrl,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Your question or request',
              alignLabelWithHint: true,
            ),
            validator: (v) => (v == null || v.trim().length < 5)
                ? 'Please write a little more'
                : null,
          ),
          const SizedBox(height: 18),
          ElevatedButton(
            onPressed: _sending ? null : _submit,
            child: _sending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Send Enquiry'),
          ),
        ],
      ),
    );

    if (widget.embedded) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Enquiry',
                  style: Theme.of(context).textTheme.headlineSmall),
            ),
          ),
          Expanded(child: body),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Enquiry')),
      body: body,
    );
  }
}
