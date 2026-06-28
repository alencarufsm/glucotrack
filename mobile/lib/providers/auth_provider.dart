import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile.dart';
import '../services/api_service.dart';

/// Gerencia o estado de autenticação do usuário.
/// Componentes que precisam saber se o usuário está logado ouvem este provider.
class AuthProvider extends ChangeNotifier {
  final ApiService _api;
  final SupabaseClient _supabase = Supabase.instance.client;

  User? _user;
  Profile? _profile;
  bool _loading = false;
  String? _error;

  AuthProvider(this._api) {
    // Escuta mudanças de autenticação do Supabase (login, logout, token refresh)
    _supabase.auth.onAuthStateChange.listen((data) {
      _user = data.session?.user;
      if (_user != null) {
        _loadProfile();
      } else {
        _profile = null;
      }
      notifyListeners();
    });
    _user = _supabase.auth.currentUser;
    if (_user != null) _loadProfile();
  }

  User? get user => _user;
  Profile? get profile => _profile;
  bool get isLoggedIn => _user != null;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> _loadProfile() async {
    try {
      _profile = await _api.getProfile();
      notifyListeners();
    } catch (_) {
      // Perfil pode não existir ainda logo após o cadastro — ignora
    }
  }

  Future<bool> login(String email, String password) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      await _supabase.auth.signInWithPassword(email: email, password: password);
      _loading = false;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _error = _translateAuthError(e.message);
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register(String name, String email, String password) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {'name': name},
      );
      _loading = false;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _error = _translateAuthError(e.message);
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _supabase.auth.signOut();
  }

  String _translateAuthError(String message) {
    if (message.contains('Invalid login')) return 'E-mail ou senha incorretos';
    if (message.contains('already registered')) return 'Este e-mail já está cadastrado';
    if (message.contains('password')) return 'Senha deve ter pelo menos 6 caracteres';
    return 'Erro ao autenticar. Tente novamente.';
  }
}
