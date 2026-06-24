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

  Future<void> logout() async {
    await _auth.signOut();
    notifyListeners();
  }

  String? get displayName => _auth.currentUser?.displayName;

  Future<bool> updateUsername(String newUsername) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _auth.currentUser?.updateDisplayName(newUsername.trim());
      await _auth.currentUser?.reload();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Gagal mengubah username: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = _auth.currentUser;
      if (user == null || user.email == null) {
        _isLoading = false;
        _errorMessage = 'Pengguna tidak ditemukan.';
        notifyListeners();
        return false;
      }

      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);

      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      switch (e.code) {
        case 'wrong-password':
        case 'invalid-credential':
          _errorMessage = 'Password saat ini salah.';
          break;
        case 'weak-password':
          _errorMessage = 'Password baru terlalu lemah (minimal 6 karakter).';
          break;
        case 'requires-recent-login':
          _errorMessage = 'Sesi kadaluarsa. Silakan login ulang.';
          break;
        default:
          _errorMessage = 'Gagal mengubah password: ${e.message}';
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

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
