import 'dart:io' show File;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../utils/lang_rebuild.dart';
import '../utils/lang_scope.dart';
import '../services/profile_service.dart';
import '../utils/player_name.dart';
import 'profile/profile_cosmic_ui.dart';

class EditProfileDialog extends StatefulWidget {
  const EditProfileDialog({super.key, required this.profile});

  final PlayerProfile profile;

  static Future<bool?> show(BuildContext context, PlayerProfile profile) {
    return showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Edit Profile',
      barrierColor: Colors.black.withValues(alpha: 0.62),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, animation, secondaryAnimation) {
        return LangRebuild(child: EditProfileDialog(profile: profile));
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
    final lang = context.lang;
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
          ProfileUpdateError.usernameReserved =>
            lang.t('profile_username_reserved'),
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
    final lang = context.lang;

    return ProfileCosmicDialogFrame(
      widthFactor: 0.88,
      maxWidth: 400,
      maxHeight: 520,
      intrinsicHeight: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ProfileCosmicHeader(
              title: lang.t('profile_edit'),
              closeEnabled: !_saving,
              onClose: () => Navigator.of(context).pop(false),
            ),
            const SizedBox(height: 12),
            Center(
              child: GestureDetector(
                onTap: _saving ? null : _pickAvatar,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    _buildAvatarPreview(),
                    if (!_saving)
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00F0FF),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF060818),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF00F0FF)
                                    .withValues(alpha: 0.45),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.camera_alt_rounded,
                            size: 18,
                            color: Color(0xFF060818),
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
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              lang.t('profile_edit_name'),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.65),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            ProfileCosmicTextField(
              controller: _nameController,
              enabled: !_saving,
              maxLength: maxPlayerNameLength,
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
                        color: const Color(0xFF00F0FF).withValues(alpha: 0.28),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
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
                      foregroundColor: const Color(0xFF060818),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                      shadowColor: const Color(0xFF00F0FF).withValues(alpha: 0.4),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF060818),
                            ),
                          )
                        : Text(
                            lang.t('profile_edit_save'),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarPreview() {
    if (_pickedFile != null) {
      return Container(
        padding: const EdgeInsets.all(3),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [Color(0xFF00F0FF), Color(0xFFFF2D95)],
          ),
        ),
        child: ClipOval(
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
        ),
      );
    }
    return ProfileOrbitAvatar(
      avatarUrl: _previewAvatarUrl,
      editIcon: Icons.camera_alt_rounded,
    );
  }

  Widget _networkOrDefaultAvatar() {
    return ProfileOrbitAvatar(avatarUrl: _previewAvatarUrl);
  }
}
