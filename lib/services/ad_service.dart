import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config/app_config.dart';

/// Google Mobile Ads rewarded video integration.
class AdService {
  AdService._();
  static final AdService instance = AdService._();

  bool _initialized = false;
  bool _loading = false;
  bool _rewardedLoading = false;
  RewardedAd? _rewardedAd;
  String? _loadedUnitId;

  bool get adsSupported {
    if (kIsWeb) return false;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android || TargetPlatform.iOS => true,
      _ => false,
    };
  }

  String get _doubleAdUnitId {
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => AppConfig.androidRewardedDoubleAdUnitId,
      TargetPlatform.iOS => AppConfig.iosRewardedDoubleAdUnitId,
      _ => '',
    };
  }

  String get _reviveAdUnitId {
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => AppConfig.androidRewardedReviveAdUnitId,
      TargetPlatform.iOS => AppConfig.iosRewardedReviveAdUnitId,
      _ => '',
    };
  }

  Future<void> init() async {
    if (_initialized || !adsSupported) return;

    try {
      await MobileAds.instance.initialize();
      _initialized = true;
    } catch (e, stackTrace) {
      _initialized = false;
      debugPrint('AdService init failed: $e\n$stackTrace');
    }
    await _preloadRewardedAd(_doubleAdUnitId);
  }

  Future<bool> _preloadRewardedAd(String adUnitId) async {
    if (!adsSupported || adUnitId.isEmpty) return false;
    if (_rewardedAd != null && _loadedUnitId == adUnitId) return true;
    if (_rewardedLoading) return _rewardedAd != null && _loadedUnitId == adUnitId;

    _rewardedLoading = true;
    final completer = Completer<bool>();

    await RewardedAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd?.dispose();
          _rewardedAd = ad;
          _loadedUnitId = adUnitId;
          _rewardedLoading = false;
          if (!completer.isCompleted) completer.complete(true);
        },
        onAdFailedToLoad: (error) {
          debugPrint('RewardedAd failed to load: ${error.message}');
          _rewardedAd = null;
          _loadedUnitId = null;
          _rewardedLoading = false;
          if (!completer.isCompleted) completer.complete(false);
        },
      ),
    );

    return completer.future;
  }

  /// Shows a rewarded ad. Returns true when the reward is granted.
  ///
  /// [ssvUserId] / [ssvCustomData] are sent to AdMob SSV (server callback).
  Future<bool> showRewardedAd({
    required String adUnitId,
    String? ssvUserId,
    String? ssvCustomData,
  }) async {
    if (_loading || !adsSupported || adUnitId.isEmpty) return false;

    if (!_initialized) {
      await init();
    }

    var ad = _rewardedAd;
    if (ad == null || _loadedUnitId != adUnitId) {
      _rewardedAd?.dispose();
      _rewardedAd = null;
      _loadedUnitId = null;
      final loaded = await _preloadRewardedAd(adUnitId);
      if (!loaded) return false;
      ad = _rewardedAd;
      if (ad == null) return false;
    }

    _loading = true;
    _rewardedAd = null;
    _loadedUnitId = null;

    var earned = false;
    final completer = Completer<bool>();

    try {
      if ((ssvUserId != null && ssvUserId.isNotEmpty) ||
          (ssvCustomData != null && ssvCustomData.isNotEmpty)) {
        await ad.setServerSideOptions(
          ServerSideVerificationOptions(
            userId: ssvUserId,
            customData: ssvCustomData,
          ),
        );
      }

      ad.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          unawaited(_preloadRewardedAd(adUnitId));
          _loading = false;
          if (!completer.isCompleted) completer.complete(earned);
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          debugPrint('RewardedAd failed to show: ${error.message}');
          ad.dispose();
          unawaited(_preloadRewardedAd(adUnitId));
          _loading = false;
          if (!completer.isCompleted) completer.complete(false);
        },
      );

      await ad.show(
        onUserEarnedReward: (ad, reward) {
          earned = true;
        },
      );

      return completer.future;
    } catch (e, stackTrace) {
      debugPrint('RewardedAd show error: $e\n$stackTrace');
      _loading = false;
      unawaited(_preloadRewardedAd(adUnitId));
      return false;
    }
  }

  Future<bool> showRewardedDoubleAd({
    String? ssvUserId,
    String? ssvCustomData,
  }) =>
      showRewardedAd(
        adUnitId: _doubleAdUnitId,
        ssvUserId: ssvUserId,
        ssvCustomData: ssvCustomData,
      );

  /// Reserved for a later revive flow.
  Future<bool> showRewardedReviveAd() =>
      showRewardedAd(adUnitId: _reviveAdUnitId);
}
