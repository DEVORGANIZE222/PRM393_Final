import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:firebase_remote_config/firebase_remote_config.dart';

import '../services/services.dart';

/// Firebase Remote Config implementation with fallback defaults.
class FirebaseRemoteConfigService implements ConfigService {
  FirebaseRemoteConfigService([FirebaseRemoteConfig? remoteConfig])
    : _remoteConfig = remoteConfig ?? FirebaseRemoteConfig.instance;
  final FirebaseRemoteConfig _remoteConfig;
  final _changesController = StreamController<void>.broadcast();

  Future<void> initialize() async {
    await _remoteConfig.setConfigSettings(
      RemoteConfigSettings(fetchTimeout: const Duration(seconds: 10), minimumFetchInterval: const Duration(hours: 1)),
    );
    await _remoteConfig.setDefaults(ConfigKeys.defaults);
    try {
      await refresh();
    } catch (e, st) {
      // A failed fetch must not block start-up: keep the in-app defaults, but
      // keep the cause visible (GR-04: the old message dropped the error).
      debugPrint('RemoteConfig fetch failed on startup, using in-app defaults: $e');
      debugPrintStack(stackTrace: st, maxFrames: 5);
    }
    _remoteConfig.onConfigUpdated.listen((_) async {
      try {
        await _remoteConfig.activate();
        _changesController.add(null);
      } catch (_) {
        // Keep the last activated/default configuration on update failure.
      }
    });
  }

  @override
  Stream<void> get changes => _changesController.stream;

  @override
  int getInt(String key) {
    return _remoteConfig.getInt(key);
  }

  @override
  bool getBool(String key) {
    return _remoteConfig.getBool(key);
  }

  @override
  Future<bool> refresh() async {
    if (kDebugMode) {
      await _remoteConfig.setConfigSettings(
        RemoteConfigSettings(fetchTimeout: const Duration(seconds: 10), minimumFetchInterval: Duration.zero),
      );
    }
    final changed = await _remoteConfig.fetchAndActivate();
    if (changed) _changesController.add(null);
    return changed;
  }
}
