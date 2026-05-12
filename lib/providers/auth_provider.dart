import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';
import '../models/auth_state.dart';
import '../models/user.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  AuthState _authState = const AuthState();
  AuthState get authState => _authState;

  bool get isAuthenticated => _authState.status == AuthStatus.authenticated;
  bool get isLoading => _authState.status == AuthStatus.loading;
  User? get currentUser => _authState.user;
  String? get errorMessage => _authState.errorMessage;

  AuthProvider() {
    _initializeAuth();
  }

  void _initializeAuth() {
    _authService.authStateChanges.listen((authState) {
      _authState = authState;
      notifyListeners();
    });
  }

  Future<void> signInWithEmailAndPassword(String email, String password) async {
    _authState = const AuthState(status: AuthStatus.loading);
    notifyListeners();

    final result =
        await _authService.signInWithEmailAndPassword(email, password);
    _authState = result;
    notifyListeners();
  }

  Future<void> registerWithEmailAndPassword(
    String email,
    String password,
    String? displayName,
  ) async {
    _authState = const AuthState(status: AuthStatus.loading);
    notifyListeners();

    final result = await _authService.registerWithEmailAndPassword(
      email,
      password,
      displayName,
    );
    _authState = result;
    notifyListeners();
  }

  Future<void> signInWithGoogle() async {
    _authState = const AuthState(status: AuthStatus.loading);
    notifyListeners();

    final result = await _authService.signInWithGoogle();
    _authState = result;
    notifyListeners();
  }

  Future<void> signOut() async {
    await _authService.signOut();
  }

  Future<void> deleteAccount() async {
    await _authService.deleteAccount();
  }

  Future<void> resetPassword(String email) async {
    await _authService.resetPassword(email);
  }

  Future<void> updateProfile({
    String? displayName,
    String? phoneNumber,
    String? photoUrl,
  }) async {
    await _authService.updateProfile(
      displayName: displayName,
      phoneNumber: phoneNumber,
      photoUrl: photoUrl,
    );

    // Refresh user data
    final updatedUser = await _authService.getCurrentUser();
    if (updatedUser != null) {
      _authState = _authState.copyWith(user: updatedUser);
      notifyListeners();
    }
  }

  Future<void> updatePreferences({
    bool? notificationsEnabled,
    bool? locationSharingEnabled,
    String? defaultTransportMode,
    bool? darkMode,
    String? language,
  }) async {
    final currentUser = _authState.user;
    if (currentUser == null) return;

    final updatedPreferences = UserPreferences(
      notificationsEnabled: notificationsEnabled ?? currentUser.preferences.notificationsEnabled,
      locationSharingEnabled: locationSharingEnabled ?? currentUser.preferences.locationSharingEnabled,
      defaultTransportMode: defaultTransportMode ?? currentUser.preferences.defaultTransportMode,
      darkMode: darkMode ?? currentUser.preferences.darkMode,
      language: language ?? currentUser.preferences.language,
    );

    await _authService.updateUserPreferences(currentUser.id, updatedPreferences);
    
    // Refresh user data
    final updatedUser = await _authService.getCurrentUser();
    if (updatedUser != null) {
      _authState = _authState.copyWith(user: updatedUser);
      notifyListeners();
    }
  }

  Future<void> refreshUserData() async {
    try {
      final updatedUser = await _authService.getCurrentUser();
      if (updatedUser != null) {
        _authState = _authState.copyWith(user: updatedUser);
        notifyListeners();
      }
    } catch (e) {
      _authState = _authState.copyWith(errorMessage: e.toString());
      notifyListeners();
    }
  }

  void clearError() {
    _authState = _authState.copyWith(errorMessage: null);
    notifyListeners();
  }
}
