import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../app_theme.dart';
import '../models/offer.dart';
import '../services/offer_service.dart';

/// Home-page promo banners: add, disable, or delete any time -- the
/// customer app's home screen shows every active one as a carousel
/// (auto-swiping when there's more than one), no app update needed.
class OffersScreen extends StatefulWidget {
  const OffersScreen({super.key});

  @override
  State<OffersScreen> createState() => _OffersScreenState();
}

class _OffersScreenState extends State<OffersScreen> {
  late Future<List<Offer>> _future;

  @override
  void initState() {
    super.initState();
    _future = offerService.listOffers();
  }

  Future<void> _refresh() async {
    setState(() => _future = offerService.listOffers());
    await _future;
  }

  Future<void> _addOffer() async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _AddOfferSheet(),
    );
    if (added == true) await _refresh();
  }

  Future<void> _delete(Offer offer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete offer?'),
        content: Text('Remove "${offer.title}" from the home page carousel?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await offerService.deleteOffer(offer.id);
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not delete: $e')));
    }
  }

  Widget _thumbnail(String source) {
    Widget child;
    if (source.isEmpty) {
      child = const Icon(Icons.local_offer_outlined, color: AppBranding.textMuted);
    } else if (source.startsWith('data:')) {
      try {
        child = Image.memory(base64Decode(source.substring(source.indexOf(',') + 1)), fit: BoxFit.cover);
      } catch (_) {
        child = const Icon(Icons.broken_image_outlined, color: AppBranding.textMuted);
      }
    } else {
      child = Image.network(source, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined));
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(height: 52, width: 52, child: Container(color: Colors.grey.shade200, child: child)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Offers')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addOffer,
        icon: const Icon(Icons.add),
        label: const Text('Add offer'),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<Offer>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return ListView(children: [
                const SizedBox(height: 80),
                Center(child: Text('Could not load offers.\n${snapshot.error}', textAlign: TextAlign.center)),
              ]);
            }
            final offers = snapshot.data ?? [];
            if (offers.isEmpty) {
              return ListView(children: const [
                SizedBox(height: 100),
                Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      'No offers yet. Add one to show it in a carousel on the customer app\'s home page.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppBranding.textMuted),
                    ),
                  ),
                ),
              ]);
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
              itemCount: offers.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final offer = offers[i];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  leading: _thumbnail(offer.imageUrl),
                  title: Text(offer.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: offer.subtitle.isEmpty
                      ? null
                      : Text(offer.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Switch(
                        value: offer.isActive,
                        activeThumbColor: AppBranding.success,
                        onChanged: (v) async {
                          setState(() => offers[i] = offer.copyWith(isActive: v));
                          try {
                            await offerService.setActive(offer.id, v);
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update: $e')));
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: AppBranding.danger),
                        onPressed: () => _delete(offer),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _AddOfferSheet extends StatefulWidget {
  const _AddOfferSheet();

  @override
  State<_AddOfferSheet> createState() => _AddOfferSheetState();
}

class _AddOfferSheetState extends State<_AddOfferSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _subtitleCtrl = TextEditingController();
  File? _pickedImageFile;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _subtitleCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1200, imageQuality: 75);
    if (picked == null) return;
    setState(() => _pickedImageFile = File(picked.path));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_pickedImageFile == null) {
      setState(() => _error = 'Please add a photo for the banner.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final offer = await offerService.createOffer(title: _titleCtrl.text.trim(), subtitle: _subtitleCtrl.text.trim());
      await offerService.uploadImage(offer.id, _pickedImageFile!);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _error = 'Could not add offer: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Add offer', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _pickImage,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    height: 130,
                    width: double.infinity,
                    color: Colors.grey.shade200,
                    child: _pickedImageFile != null
                        ? Image.file(_pickedImageFile!, fit: BoxFit.cover)
                        : const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add_photo_alternate_outlined, size: 32, color: AppBranding.textMuted),
                                SizedBox(height: 4),
                                Text('Tap to add a banner photo', style: TextStyle(fontSize: 12, color: AppBranding.textMuted)),
                              ],
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a title' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _subtitleCtrl,
                decoration: const InputDecoration(labelText: 'Subtitle (optional)'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: AppBranding.danger)),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Add offer'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
