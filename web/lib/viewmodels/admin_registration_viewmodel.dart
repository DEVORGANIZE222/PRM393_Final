import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/registration_configuration.dart';
import '../services/admin_registration_service.dart';

class AdminRegistrationViewModel extends ChangeNotifier {
  AdminRegistrationViewModel(this._service);
  final AdminRegistrationService _service;
  StreamSubscription<RegistrationConfiguration?>? _subscription;

  RegistrationConfiguration? configuration;
  String? error;
  bool loading = true;
  bool saving = false;

  void load() {
    _subscription?.cancel();
    loading = true;
    error = null;
    notifyListeners();
    _subscription = _service.watchCurrent().listen(
      (value) {
        configuration = value;
        loading = false;
        notifyListeners();
      },
      onError: (_) {
        error = 'Cannot load the active semester. Check your Firebase Admin access.';
        loading = false;
        notifyListeners();
      },
    );
  }

  Future<bool> save(RegistrationConfiguration value) async {
    if (value.semester.trim().isEmpty) {
      error = 'Semester name is required.';
      notifyListeners();
      return false;
    }
    if (!value.closesAt.isAfter(value.opensAt)) {
      error = 'Registration closing time must be after opening time.';
      notifyListeners();
      return false;
    }
    saving = true;
    error = null;
    notifyListeners();
    try {
      await _service.save(value);
      return true;
    } catch (_) {
      error = 'Could not save the registration window. Check your Firebase Admin access.';
      return false;
    } finally {
      saving = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
