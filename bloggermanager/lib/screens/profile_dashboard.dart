import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/firebase_service.dart';
import 'profile_list.dart';

class ProfileDashboard extends StatefulWidget {
  const ProfileDashboard({super.key});

  @override
  State<ProfileDashboard> createState() => _ProfileDashboardState();
}

class _ProfileDashboardState extends State<ProfileDashboard> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtl = TextEditingController();
  final _bioCtl = TextEditingController();
  XFile? _pickedImage;
  bool _isUploading = false;

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (file != null) {
      setState(() {
        _pickedImage = file;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isUploading = true);
    try {
      String? imageUrl;
      if (_pickedImage != null) {
        imageUrl = await FirebaseService.uploadProfileImage(_pickedImage!);
      }

      await FirebaseService.saveProfile({
        'name': _nameCtl.text.trim(),
        'bio': _bioCtl.text.trim(),
        'imageUrl': imageUrl,
        'createdAt': DateTime.now(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile uploaded')));
      _nameCtl.clear();
      _bioCtl.clear();
      setState(() => _pickedImage = null);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _bioCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.list),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfileListScreen())),
            tooltip: 'View profiles',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
            tooltip: 'Sign out',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GestureDetector(
                onTap: _pickImage,
                child: Center(
                  child: _pickedImage == null
                      ? CircleAvatar(
                          radius: 56,
                          child: Icon(Icons.camera_alt, size: 32, color: Theme.of(context).colorScheme.onPrimary),
                        )
                      : CircleAvatar(
                          radius: 56,
                          backgroundImage: FileImage(File(_pickedImage!.path)),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameCtl,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter a name' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _bioCtl,
                decoration: const InputDecoration(labelText: 'Bio'),
                maxLines: 3,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _isUploading ? null : _submit,
                icon: _isUploading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.upload),
                label: Text(_isUploading ? 'Uploading...' : 'Upload Profile'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
