import 'package:core/core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String? _errorMessage;
  bool _isLoading = false;

  void _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Without the FIREBASE_WEB_* values there is no backend to sign in to:
    // keep the local layout preview working.
    if (Firebase.apps.isEmpty) {
      setState(() => _isLoading = false);
      context.go('/admin');
      return;
    }

    try {
      final user = (await FirebaseAuth.instance.signInWithPopup(GoogleAuthProvider())).user!;
      final profile = await SharedFirestoreService().getUserProfile(user.uid);
      if (profile == null || !profile.isStaff) {
        await FirebaseAuth.instance.signOut();
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'This account is not staff. Ask an admin to change its role.';
          });
        }
        return;
      }
      if (mounted) {
        setState(() => _isLoading = false);
        context.go('/admin');
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.code == 'popup-closed-by-user' ? null : 'Sign-in failed: ${e.message ?? e.code}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Container(
          width: 420,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.admin_panel_settings, size: 48, color: Color(0xFF107C41)),
              const SizedBox(height: 16),
              const Text(
                'Staff & Admin Portal',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Sign in with your authorized @fpt.edu.vn account to manage teams and review submissions.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.black54),
              ),
              const SizedBox(height: 24),
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: Colors.red.shade700, fontSize: 13),
                  ),
                ),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _handleGoogleSignIn,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF107C41),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.login),
                label: const Text('Sign in with Google (Staff/Admin)'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

