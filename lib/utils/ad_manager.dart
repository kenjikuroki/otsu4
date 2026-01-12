import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';

class PreloadedAd {
  final BannerAd ad;
  final ValueNotifier<bool> isLoaded = ValueNotifier(false);

  PreloadedAd(this.ad);

  void dispose() {
    ad.dispose();
    isLoaded.dispose();
  }
}

class AdManager {
  static final AdManager instance = AdManager._internal();
  AdManager._internal();

  final Map<String, PreloadedAd> _ads = {};

  final String _adUnitId = 'ca-app-pub-3331079517737737/8905948804';
  
  // Test ID for debug (optional use)
  // final String _testAdUnitId = 'ca-app-pub-3940256099942544/6300978111';

  /// Initialize Consent Flow (UMP)
  /// Returns a Future that completes when consent gathering is finished (or failed).
  /// Initialize Consent Flow (iOS ATT)
  /// Returns a Future that completes when consent gathering is finished (or failed).
  Future<void> initializeConsent() async {
    // iOSでのトラッキング許可ダイアログを直接呼び出し
    try {
      final status = await AppTrackingTransparency.trackingAuthorizationStatus;
      if (status == TrackingStatus.notDetermined) {
        // ダイアログ表示
        await AppTrackingTransparency.requestTrackingAuthorization();
      }
    } catch (e) {
      debugPrint("ATT Error: $e");
    }
  }

  void preloadAd(String key) {
    if (_ads.containsKey(key)) {
      // Already preloading or loaded
      return;
    }

    // Always use the real ID as requested by user, 
    // or switch to test ID if strictly debugging.
    // final unitId = kDebugMode ? _testAdUnitId : _adUnitId;
    final unitId = _adUnitId;

    final ad = BannerAd(
      adUnitId: unitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          debugPrint('AdManager: Ad $key loaded.');
          _ads[key]?.isLoaded.value = true;
        },
        onAdFailedToLoad: (ad, err) {
          debugPrint('AdManager: Ad $key failed to load: $err');
          ad.dispose();
          _ads.remove(key);
        },
      ),
    );

    final preloadedAd = PreloadedAd(ad);
    _ads[key] = preloadedAd;
    ad.load();
  }

  PreloadedAd? getAd(String key) {
    return _ads[key];
  }
  
  /// Returns the ad and removes it from manager (transfer ownership)
  /// If [keep] is true, it retains in manager (shared ownership/singleton usage like Home).
  PreloadedAd? consumeAd(String key, {bool keep = false}) {
    if (keep) {
      return _ads[key];
    }
    return _ads.remove(key);
  }

  // Interstitial Ad
  InterstitialAd? _interstitialAd;
  
  // Real ID from user screenshot
  final String _interstitialAdUnitId = 'ca-app-pub-3331079517737737/4723161214';

  void preloadInterstitial() {
    // If already loaded or loading, skip? 
    // Simplified: just try to load if null.
    if (_interstitialAd != null) return;

    InterstitialAd.load(
      adUnitId: _interstitialAdUnitId, 
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('AdManager: Interstitial loaded.');
          _interstitialAd = ad;
        },
        onAdFailedToLoad: (err) {
          debugPrint('AdManager: Interstitial failed to load: $err');
          _interstitialAd = null;
        },
      ),
    );
  }

  /// Shows the interstitial ad if available.
  /// [onComplete] is called when the ad is dismissed or if it fails to show/load.
  void showInterstitial({required VoidCallback onComplete}) {
    if (_interstitialAd == null) {
      debugPrint('AdManager: No interstitial ready, skipping.');
      onComplete();
      return;
    }

    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        debugPrint('AdManager: Interstitial dismissed.');
        ad.dispose();
        _interstitialAd = null;
        onComplete();
      },
      onAdFailedToShowFullScreenContent: (ad, err) {
        debugPrint('AdManager: Interstitial failed to show: $err');
        ad.dispose();
        _interstitialAd = null;
        onComplete();
      },
    );

    _interstitialAd!.show();
    // Note: don't set null here immediately, wait for callbacks
  }
  
  void disposeAll() {
    for (var ad in _ads.values) {
      ad.dispose();
    }
    _ads.clear();
    _interstitialAd?.dispose();
    _interstitialAd = null;
  }
}
