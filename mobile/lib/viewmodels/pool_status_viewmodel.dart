import 'package:flutter/foundation.dart';

import '../models/registration.dart';
import '../models/student.dart';
import '../models/view_state.dart';
import '../services/services.dart';
import 'guard.dart';

/// SCR_08: Random Pool status after the deadline.
class PoolStatusViewModel extends ChangeNotifier {
  PoolStatusViewModel(this._student, this._pool, this._crash);

  final Student _student;
  final PoolRepository _pool;
  final CrashReporter _crash;

  ViewState<PoolStatus> state = const Loading();
  bool refreshing = false;

  Student get student => _student;

  Future<void> load({bool userRefresh = false}) async {
    if (userRefresh) {
      refreshing = true;
    } else {
      state = const Loading();
    }
    notifyListeners();
    try {
      state = Data(await _pool.statusOf(_student.id));
    } catch (e, st) {
      state = Failure(await toFailure(e, st, crash: _crash, reason: 'pool_status'));
    } finally {
      refreshing = false;
      notifyListeners();
    }
  }
}
