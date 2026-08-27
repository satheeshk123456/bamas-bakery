import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../app_theme.dart';
import '../models/category.dart';
import '../models/menu_item.dart';
import '../services/menu_service.dart';

/// Lets a shop owner add a brand-new item to the menu: name, description,
/// category, price ("rate"), and an optional photo. Saving here is what
/// makes the item show up on the customer-facing `bamas` app's Menu tab.
/// Reached from the "+" (add) icon on [MenuAvailabilityScreen]'s app bar.
class MenuAddScreen extends StatefulWidget {
  const MenuAddScreen({super.key});

  @override
  State<MenuAddScreen> createState() => _MenuAddScreenState();
}

class _MenuAddScreenState extends State<MenuAddScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();

  late final Future<List<Category>> _categoriesFuture;
  String? _categoryId;
  File? _pickedImageFile;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _categoriesFuture = menuService.listCategories();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
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
    if (_categoryId == null) {
      setState(() => _error = 'Please choose a category.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      var item = await menuService.createItem(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        price: double.parse(_priceController.text.trim()),
        categoryId: _categoryId!,
      );
      if (_pickedImageFile != null) {
        final imageUrl = await menuService.uploadImage(item.id, _pickedImageFile!);
        item = await menuService.updateItem(item.copyWith(imageUrl: imageUrl));
      }
      if (!mounted) return;
      Navigator.of(context).pop(item);
    } catch (e) {
      setState(() => _error = 'Could not add item: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add menu item')),
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
                label: Text(_pickedImageFile == null ? 'Add photo' : 'Change photo'),
              ),
              const SizedBox(height: 12),
              Text('Name', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(hintText: 'e.g. Classic Beef Burger'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
              ),
              const SizedBox(height: 16),
              Text('Description', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                maxLines: 2,
                decoration: const InputDecoration(hintText: 'Short description (optional)'),
              ),
              const SizedBox(height: 16),
              Text('Category', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              FutureBuilder<List<Category>>(
                future: _categoriesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const LinearProgressIndicator();
                  }
                  if (snapshot.hasError) {
                    return Text(
                      'Could not load categories.\n${snapshot.error}',
                      style: const TextStyle(color: AppBranding.danger),
                    );
                  }
                  final categories = snapshot.data ?? [];
                  return DropdownButtonFormField<String>(
                    value: _categoryId,
                    hint: const Text('Select category'),
                    items: categories
                        .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                        .toList(),
                    onChanged: (value) => setState(() => _categoryId = value),
                  );
                },
              ),
              const SizedBox(height: 16),
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
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: const TextStyle(color: AppBranding.danger)),
              ],
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Add item'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
