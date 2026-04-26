import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AppAuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;
  bool get isLoggedIn => _auth.currentUser != null;
  String? get userEmail => _auth.currentUser?.email;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  /// Sign in with email and password (Admin only)
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      switch (e.code) {
        case 'user-not-found':
          _errorMessage = 'Akun admin tidak ditemukan.';
          break;
        case 'wrong-password':
          _errorMessage = 'Password salah. Silakan coba lagi.';
          break;
        case 'invalid-email':
          _errorMessage = 'Format email tidak valid.';
          break;
        case 'invalid-credential':
          _errorMessage = 'Email atau password salah.';
          break;
        case 'too-many-requests':
          _errorMessage = 'Terlalu banyak percobaan. Coba lagi nanti.';
          break;
        default:
          _errorMessage = 'Login gagal: ${e.message}';
      }
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Terjadi kesalahan: $e';
      notifyListeners();
      return false;
    }
  }

  /// Sign out
  Future<void> logout() async {
    await _auth.signOut();
    notifyListeners();
  }

  /// Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
