import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spark_app/controllers/energy_controller.dart';
import 'package:spark_app/models/user_model.dart';
import 'package:spark_app/services/user_service.dart';

/// StreamProvider global que escuta o documento do usuário logado no Firestore.
///
/// Sempre que um novo [UserModel] chega, sincroniza o [EnergyController]
/// singleton para manter energia, XP e Spark Points atualizados na UI.
///
/// Uso:
/// ```dart
/// final userAsync = ref.watch(userProvider);
/// userAsync.when(
///   data: (user) => user != null ? Text(user.name) : Text('Sem dados'),
///   loading: () => CircularProgressIndicator(),
///   error: (e, _) => Text('Erro: $e'),
/// );
/// ```
final userProvider = StreamProvider<UserModel?>((ref) {
  final firebaseUser = FirebaseAuth.instance.currentUser;
  if (firebaseUser == null) return Stream.value(null);

  return UserService().watchUser(firebaseUser.uid).map((userModel) {
    // Mantém o singleton de energia sincronizado com os dados do Firestore.
    EnergyController().loadUser(userModel);
    return userModel;
  });
});