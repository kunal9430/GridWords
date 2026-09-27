import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:characters/characters.dart';
import 'package:image_picker/image_picker.dart';
import '../services/profile_service.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  static const int _maxNameLength = 20;
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  bool _loading = true;
  bool _saving = false;

  // Snapshot of whatever was loaded from storage, so Save can tell
  // whether the player actually changed anything (see _hasChanges).
  Profile _original = const Profile();
  String? _photoBase64; // current photo, may differ from _original.photoBase64

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = await ProfileService.loadProfile();
    if (!mounted) return;
    setState(() {
      _original = profile;
      _nameController.text = profile.name;
      _emailController.text = profile.email;
      _photoBase64 = profile.photoBase64;
      _loading = false;
    });
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) return null; // name is optional
    if (value.trim().characters.length > _maxNameLength) {
      return 'Max $_maxNameLength characters';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return null; // email is optional
    final trimmed = value.trim();
    final pattern = RegExp(r'^[\w\.\-\+]+@[\w\-]+\.[\w\-\.]+$');
    if (!pattern.hasMatch(trimmed)) {
      return 'Enter a valid email address';
    }
    return null;
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final XFile? picked = await picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );
      if (picked == null || !mounted) return;
      final Uint8List bytes = await picked.readAsBytes();
      setState(() => _photoBase64 = base64Encode(bytes));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't open the photo picker on this device.")),
      );
    }
  }

  void _removePhoto() => setState(() => _photoBase64 = null);

  void _showPhotoSourceSheet() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _pickPhoto(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a Photo'),
              onTap: () {
                Navigator.pop(ctx);
                _pickPhoto(ImageSource.camera);
              },
            ),
            if (_photoBase64 != null && _photoBase64!.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Remove Photo', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(ctx);
                  _removePhoto();
                },
              ),
          ],
        ),
      ),
    );
  }

  /// Only the fields that actually differ from what was loaded count as
  /// "changed" — so a Save tap that didn't touch anything can say so
  /// honestly instead of always claiming an update happened.
  bool get _hasChanges =>
      _nameController.text.trim() != _original.name ||
      _emailController.text.trim() != _original.email ||
      (_photoBase64 ?? '') != (_original.photoBase64 ?? '');

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_hasChanges) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No changes made')),
      );
      Navigator.pop(context);
      return;
    }

    setState(() => _saving = true);
    final updated = Profile(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      photoBase64: _photoBase64,
    );
    await ProfileService.saveProfile(updated);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile updated')),
    );
    Navigator.pop(context, true);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: GestureDetector(
                          onTap: _showPhotoSourceSheet,
                          child: Stack(
                            children: [
                              CircleAvatar(
                                radius: 48,
                                backgroundColor: primary.withOpacity(0.15),
                                backgroundImage: (_photoBase64 != null && _photoBase64!.isNotEmpty)
                                    ? MemoryImage(base64Decode(_photoBase64!))
                                    : null,
                                child: (_photoBase64 == null || _photoBase64!.isEmpty)
                                    ? Icon(Icons.person, size: 48, color: primary)
                                    : null,
                              ),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: primary,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 2),
                                  ),
                                  child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: TextButton(
                          onPressed: _showPhotoSourceSheet,
                          child: const Text('Change Photo'),
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Your Name',
                          helperText: 'Used as Player 1\'s name',
                        ),
                        maxLength: _maxNameLength,
                        validator: _validateName,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: 'Email (optional)',
                          helperText: 'Not used for sign-in',
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: _validateEmail,
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _saving ? null : _save,
                          child: _saving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('Save'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
