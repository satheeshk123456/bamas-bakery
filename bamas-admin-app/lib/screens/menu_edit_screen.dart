import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../app_theme.dart';
import '../models/menu_item.dart';
import '../services/menu_service.dart';

enum _OfferType { none, percent, amount }

/// Lets a shop owner manually update a single menu item's photo, price
/// ("rate"), and a promotional offer — everything that shows up on the
/// customer-facing `bamas` app for that item.
class MenuEditScreen extends StatefulWidget {
  final MenuItem item;
  const MenuEditScreen({super.key, required this.item});

  @override
  State<MenuEditScreen> createState() => _MenuEditScreenState();
}

class _MenuEditScreenState extends State<MenuEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _priceController;
  late final TextEditingController _discountController;
  late final TextEditingController _offerLabelController;

  File? _pickedImageFile; // newly picked, not uploaded yet
  String? _imageUrl; // existing (or just-uploaded) remote/local image ref
  late _OfferType _offerType;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _priceController = TextEditingController(text: item.price == item.price.roundToDouble() ? item.price.toStringAsFixed(0) : item.price.toString());
    _offerType = item.discountPercent != null && item.discountPercent! > 0
        ? _OfferType.percent
        : item.discountAmount != null && item.discountAmount! > 0
            ? _OfferType.amount
            : _OfferType.none;
    final discountValue = _offerType == _OfferType.percent
        ? item.discountPercent
        : _offerType == _OfferType.amount
            ? item.discountAmount
            : null;
    _discountController = TextEditingController(text: discountValue == null ? '' : (discountValue == discountValue.roundToDouble() ? discountValue.toStringAsFixed(0) : discountValue.toString()));
    _offerLabelController = TextEditingController(text: item.offerLabel ?? '');
    _imageUrl = item.imageUrl;
  }

  @override
  void dispose() {
    _priceController.dispose();
    _discountController.dispose();
    _offerLabelController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    setState(() => _pickedImageFile = File(picked.path));
  }

  Widget _imagePreview() {
    Widget child;
    if (_pickedImageFile != null) {
      child = Image.file(_pickedImageFile!, fit: BoxFit.cover);
    } else if (_imageUrl != null && _imageUrl!.startsWith('http')) {
      child = Image.network(
        _imageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined, size: 48, color: AppBranding.textMuted),
      );
    } else if (_imageUrl != null && _imageUrl!.isNotEmpty) {
      child = Image.file(File(_imageUrl!), fit: BoxFit.cover);
    } else {
      child = const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_photo_alternate_outlined, size: 40, color: AppBranding.textMuted),
            SizedBox(height: 6),
            Text('Tap to add a photo', style: TextStyle(color: AppBranding.textMuted, fontSize: 12)),
          ],
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(color: Colors.grey.shade200, height: 200, width: double.infinity, child: child),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      var imageUrl = _imageUrl;
      if (_pickedImageFile != null) {
        imageUrl = await menuService.uploadImage(widget.item.id, _pickedImageFile!);
      }

      final price = double.parse(_priceController.text.trim());
      double? discountPercent;
      double? discountAmount;
      if (_offerType != _OfferType.none && _discountController.text.trim().isNotEmpty) {
        final value = double.parse(_discountController.text.trim());
        if (_offerType == _OfferType.percent) {
          discountPercent = value;
        } else {
          discountAmount = value;
        }
      }
      final offerLabel = _offerLabelController.text.trim().isEmpty ? null : _offerLabelController.text.trim();

      final updated = widget.item.copyWith(
        price: price,
        imageUrl: imageUrl,
        clearImageUrl: imageUrl == null,
        discountPercent: discountPercent,
        clearDiscountPercent: discountPercent == null,
        discountAmount: discountAmount,
        clearDiscountAmount: discountAmount == null,
        offerLabel: offerLabel,
        clearOfferLabel: offerLabel == null,
      );
      final saved = await menuService.updateItem(updated);
      if (!mounted) return;
      Navigator.of(context).pop(saved);
    } catch (e) {
      setState(() => _error = 'Could not save: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Scaffold(
      appBar: AppBar(title: Text(item.name)),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              GestureDetector(onTap: _pickImage, child: _imagePreview()),
              TextButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.image_outlined),
                label: Text(_imageUrl == null && _pickedImageFile == null ? 'Add photo' : 'Change photo'),
              ),
              const SizedBox(height: 12),
              Text('Rate (₹)', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              TextFormField(
                controller: _priceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(prefixText: '₹ '),
                validator: (v) {
                  final value = double.tryParse((v ?? '').trim());
                  if (value == null || value < 0) return 'Enter a valid price';
                  return null;
                },
              ),
              const SizedBox(height: 20),
              Text('Offer', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              SegmentedButton<_OfferType>(
                segments: const [
                  ButtonSegment(value: _OfferType.none, label: Text('None')),
                  ButtonSegment(value: _OfferType.percent, label: Text('% off')),
                  ButtonSegment(value: _OfferType.amount, label: Text('₹ off')),
                ],
                selected: {_offerType},
                onSelectionChanged: (s) => setState(() => _offerType = s.first),
              ),
              if (_offerType != _OfferType.none) ...[
                const SizedBox(height: 14),
                TextFormField(
                  controller: _discountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: _offerType == _OfferType.percent ? 'Discount %' : 'Discount amount (₹)',
                    prefixText: _offerType == _OfferType.percent ? null : '₹ ',
                    suffixText: _offerType == _OfferType.percent ? '%' : null,
                  ),
                  validator: (v) {
                    if (_offerType == _OfferType.none) return null;
                    final value = double.tryParse((v ?? '').trim());
                    if (value == null || value <= 0) return 'Enter a discount value';
                    if (_offerType == _OfferType.percent && value > 100) return 'Max 100%';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _offerLabelController,
                  decoration: const InputDecoration(labelText: 'Offer label (optional)', hintText: 'e.g. Combo Deal, Weekend Special'),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: const TextStyle(color: AppBranding.danger)),
              ],
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Save changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
