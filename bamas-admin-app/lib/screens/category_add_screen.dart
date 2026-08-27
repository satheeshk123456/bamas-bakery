import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../app_theme.dart';
import '../models/category.dart';
import '../services/menu_service.dart';

/// Adds a brand-new menu category (e.g. "Beverages", "Desserts") -- this
/// used to be impossible from the admin app: it could add items to an
/// existing category but never create a new one. Reached from the Menu
/// screen's app bar.
class CategoryAddScreen extends StatefulWidget {
  const CategoryAddScreen({super.key});

  @override
  State<CategoryAddScreen> createState() => _CategoryAddScreenState();
}

class _CategoryAddScreenState extends State<CategoryAddScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  File? _pickedImageFile;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1000, imageQuality: 80);
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
            Icon(Icons.add_photo_alternate_outlined, size: 36, color: AppBranding.textMuted),
            SizedBox(height: 6),
            Text('Tap to add a photo (optional)', style: TextStyle(color: AppBranding.textMuted, fontSize: 12)),
          ],
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(color: Colors.grey.shade200, height: 160, width: double.infinity, child: child),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      var category = await menuService.createCategory(name: _nameController.text.trim());
      if (_pickedImageFile != null) {
        await menuService.uploadCategoryImage(category.id, _pickedImageFile!);
      }
      if (!mounted) return;
      Navigator.of(context).pop(category);
    } catch (e) {
      setState(() => _error = 'Could not add category: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add category')),
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
              Text('Category name', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(hintText: 'e.g. Beverages'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
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
                    : const Text('Add category'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
