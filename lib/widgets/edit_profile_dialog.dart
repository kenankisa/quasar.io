import 'dart:io' show File;
import 'dart:ui';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/lang_service.dart';
import '../services/profile_service.dart';
import '../utils/player_name.dart';
import 'profile_avatar.dart';

class EditProfileDialog extends StatefulWidget {
  const EditProfileDialog({super.key, required this.profile});

  final PlayerProfile profile;

  static Future<bool?> show(BuildContext context, PlayerProfile profile) {
    return showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Edit Profile',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, animation, secondaryAnimation) {
        return EditProfileDialog(profile: profile);
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curve = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curve,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.94, end: 1).animate(curve),
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<EditProfileDialog> {
  late final TextEditingController _nameController;
  final _picker = ImagePicker();

  String? _previewAvatarUrl;
  XFile? _pickedFile;
  bool _saving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile.username);
    _previewAvatarUrl = widget.profile.avatarUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (file == null || !mounted) return;
    setState(() {
      _pickedFile = file;
      _errorMessage = null;
    });
  }

  Future<void> _save() async {
    final lang = LanguageService.instance;
    final name = _nameController.text.trim();
    if (!ProfileService.isValidUsername(name)) {
      setState(() => _errorMessage = lang.t('profile_username_invalid'));
      return;
    }

    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    try {
      String? avatarUrl;
      if (_pickedFile != null) {
        avatarUrl = await ProfileService.instance.uploadAvatar(_pickedFile!);
      }

      await ProfileService.instance.updateProfile(
        username: name,
        avatarUrl: avatarUrl,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ProfileUpdateException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _errorMessage = switch (e.error) {
          ProfileUpdateError.usernameTaken => lang.t('profile_username_taken'),
          ProfileUpdateError.invalidUsername =>
            lang.t('profile_username_invalid'),
          ProfileUpdateError.notAuthenticated => lang.t('profile_update_error'),
          ProfileUpdateError.unknown =>
            e.message ?? lang.t('profile_update_error'),
        };
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _errorMessage = lang.t('profile_update_error');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService.instance;
    final size = MediaQuery.sizeOf(context);

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: size.width * 0.88,
          constraints: const BoxConstraints(maxWidth: 400),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF12122A).withValues(alpha: 0.97),
                const Color(0xFF0A0A1A).withValues(alpha: 0.99),
              ],
            ),
            border: Border.all(
              color: const Color(0xFF00F0FF).withValues(alpha: 0.35),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            lang.t('profile_edit'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white54),
                          onPressed: _saving
                              ? null
                              : () => Navigator.of(context).pop(false),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: GestureDetector(
                        onTap: _saving ? null : _pickAvatar,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            _buildAvatarPreview(),
                            if (!_saving)
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF00F0FF),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color(0xFF0A0A1A),
                                      width: 2,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt,
                                    size: 18,
                                    color: Color(0xFF0A0A1A),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Center(
                      child: Text(
                        lang.t('profile_edit_avatar'),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      lang.t('profile_edit_name'),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _nameController,
                      enabled: !_saving,
                      maxLength: maxPlayerNameLength,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        counterStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.06),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: const Color(0xFF00F0FF).withValues(alpha: 0.3),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: const Color(0xFF00F0FF).withValues(alpha: 0.25),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF00F0FF),
                          ),
                        ),
                      ),
                      onChanged: (_) {
                        if (_errorMessage != null) {
                          setState(() => _errorMessage = null);
                        }
                      },
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: Color(0xFFFF6688),
                          fontSize: 13,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _saving
                                ? null
                                : () => Navigator.of(context).pop(false),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white70,
                              side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.25),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: Text(lang.t('profile_edit_cancel')),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: _saving ? null : _save,
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF00F0FF),
                              foregroundColor: const Color(0xFF0A0A1A),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: _saving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFF0A0A1A),
                                    ),
                                  )
                                : Text(lang.t('profile_edit_save')),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarPreview() {
    if (_pickedFile != null) {
      return ClipOval(
        child: SizedBox(
          width: 104,
          height: 104,
          child: kIsWeb
              ? Image.network(
                  _pickedFile!.path,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _networkOrDefaultAvatar(),
                )
              : Image.file(
                  File(_pickedFile!.path),
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _networkOrDefaultAvatar(),
                ),
        ),
      );
    }
    return _networkOrDefaultAvatar();
  }

  Widget _networkOrDefaultAvatar() {
    return ProfileAvatar(
      avatarUrl: _previewAvatarUrl,
      radius: 52,
      iconSize: 48,
    );
  }
}
