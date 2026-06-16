import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:spark_app/services/user_service.dart';
import 'package:spark_app/theme/app_theme.dart';
import 'package:spark_app/widgets/spark_snack.dart';
import 'package:spark_app/widgets/sparks_background.dart';
import 'package:spark_app/widgets/pcb_background.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _professionCtrl;
  bool _saving = false;
  String? _uid;

  // Foto de perfil
  final ImagePicker _picker = ImagePicker();
  String? _photoUrl; // URL atual (Firestore)
  Uint8List? _pickedPreview; // pré-visualização local logo após escolher
  bool _uploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    _uid = user?.uid;
    // Usa o getter do UserService (que já deriva do e-mail quando não há nome)
    // para não pré-preencher o campo com o literal "Usuário".
    _nameCtrl = TextEditingController(text: UserService().displayName);
    _emailCtrl = TextEditingController(text: user?.email ?? '');
    _professionCtrl = TextEditingController(text: '');

    if (_uid != null) {
      final u = UserService().user;
      if (mounted && u != null) {
        setState(() {
          _professionCtrl.text = u.profession ?? '';
          _photoUrl = u.photoUrl;
        });
      }
    }
  }

  /// Abre a galeria do celular, deixa o usuário escolher uma imagem e
  /// faz o upload para o Firebase Storage, atualizando a foto de perfil.
  Future<void> _pickPhoto() async {
    if (_uploadingPhoto) return;
    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (picked == null) return; // usuário cancelou

      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() {
        _pickedPreview = bytes;
        _uploadingPhoto = true;
      });

      final isPng = picked.name.toLowerCase().endsWith('.png');
      final url = await UserService().uploadProfilePhoto(
        bytes,
        contentType: isPng ? 'image/png' : 'image/jpeg',
      );

      if (!mounted) return;
      setState(() {
        _photoUrl = url;
        _uploadingPhoto = false;
      });
      SparkSnack.success(context, 'Foto de perfil atualizada!');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _uploadingPhoto = false;
        _pickedPreview = null;
      });
      SparkSnack.error(context, 'Erro ao enviar a foto: $e');
    }
  }

  void _saveProfile() async {
    if (_uid == null) return;

    setState(() => _saving = true);

    try {
      final newName = _nameCtrl.text.trim();
      final newProfession = _professionCtrl.text.trim();

      await FirebaseAuth.instance.currentUser?.updateDisplayName(newName);

      await UserService().updateProfile(
        displayName: newName,
        profession: newProfession,
      );

      if (!mounted) return;
      SparkSnack.success(context, 'Perfil atualizado com sucesso!');
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      SparkSnack.error(context, 'Erro ao atualizar: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _professionCtrl.dispose();
    super.dispose();
  }

  Widget _buildAvatar() {
    Widget avatarContent;
    if (_pickedPreview != null) {
      avatarContent = Image.memory(_pickedPreview!, fit: BoxFit.cover, width: 100, height: 100);
    } else if (_photoUrl != null && _photoUrl!.isNotEmpty) {
      avatarContent = Image.network(
        _photoUrl!,
        fit: BoxFit.cover,
        width: 100,
        height: 100,
        webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
        loadingBuilder: (_, child, progress) => progress == null
            ? child
            : const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        errorBuilder: (_, _, _) => const Icon(Icons.person, color: AppColors.textMuted, size: 48),
      );
    } else {
      avatarContent = const Icon(Icons.person, color: AppColors.textMuted, size: 48);
    }

    return GestureDetector(
      onTap: _uploadingPhoto ? null : _pickPhoto,
      child: Stack(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary, width: 3),
              color: AppColors.card,
            ),
            clipBehavior: Clip.antiAlias,
            child: Center(child: avatarContent),
          ),
          if (_uploadingPhoto)
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.5),
              ),
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
              ),
            ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SparksBackground(
      child: PcbBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text(
              'Editar Perfil',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: _buildAvatar()),
                const SizedBox(height: 8),
                const Center(
                  child: Text(
                    'Toque para alterar a foto',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 32),
                _buildFieldGroup('Nome Completo', _nameCtrl, maxLength: 50),
                const SizedBox(height: 20),
                _buildFieldGroup('Profissão', _professionCtrl, maxLength: 100),
                const SizedBox(height: 20),
                _buildFieldGroup('E-mail', _emailCtrl, maxLength: 100),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _saveProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 3))
                        : const Text(
                            'SALVAR ALTERAÇÕES',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 14),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFieldGroup(String label, TextEditingController ctrl, {int? maxLength}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.inputBackground,
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: AppColors.cardBorder.withValues(alpha: 0.5)),
          ),
          child: TextField(
            controller: ctrl,
            maxLength: maxLength,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            decoration: const InputDecoration(
              border: InputBorder.none,
              counterText: '',
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
        ),
      ],
    );
  }
}
