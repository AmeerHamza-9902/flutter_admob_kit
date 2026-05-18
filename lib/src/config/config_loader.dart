// lib/config/config_loader.dart

import 'dart:convert';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/services.dart';
import 'ads_config.dart';

class ConfigLoader {
  static const _defaultAsset = 'assets/ads_config.json';

  /// Load from Firebase Remote Config; falls back to local asset on failure.
  static Future<AdsConfig> load({
    String remoteKey = 'ads_config',
    String localAsset = _defaultAsset,
    Duration cacheExpiry = const Duration(hours: 1),
  }) async {
    try {
      final remoteConfig = FirebaseRemoteConfig.instance;
      await remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: cacheExpiry,
      ));
      await remoteConfig.fetchAndActivate();
      final jsonStr = remoteConfig.getString(remoteKey);
      if (jsonStr.isNotEmpty) {
        final map = json.decode(jsonStr) as Map<String, dynamic>;
        return AdsConfig.fromJson(map);
      }
    } catch (_) {}
    return loadFromAsset(localAsset);
  }

  /// Load from a local Flutter asset only.
  static Future<AdsConfig> loadFromAsset([String path = _defaultAsset]) async {
    try {
      final jsonStr = await rootBundle.loadString(path);
      final map = json.decode(jsonStr) as Map<String, dynamic>;
      return AdsConfig.fromJson(map);
    } catch (_) {
      return const AdsConfig();
    }
  }

  /// Load from Firebase Remote Config only.
  static Future<AdsConfig?> loadFromRemote({
    String remoteKey = 'ads_config',
    Duration cacheExpiry = const Duration(hours: 1),
  }) async {
    try {
      final remoteConfig = FirebaseRemoteConfig.instance;
      await remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: cacheExpiry,
      ));
      await remoteConfig.fetchAndActivate();
      final jsonStr = remoteConfig.getString(remoteKey);
      if (jsonStr.isNotEmpty) {
        return AdsConfig.fromJson(json.decode(jsonStr));
      }
    } catch (_) {}
    return null;
  }
}
