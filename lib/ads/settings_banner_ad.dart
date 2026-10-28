import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:video_player_app/ads/ad_config.dart';
import 'package:video_player_app/ads/ad_service.dart';
import 'package:video_player_app/widgets/app_spacing.dart';
import 'package:video_player_app/widgets/liquid_glass_surface.dart';

class SettingsBannerAd extends StatefulWidget {
  const SettingsBannerAd({super.key});

  @override
  State<SettingsBannerAd> createState() => _SettingsBannerAdState();
}

class _SettingsBannerAdState extends State<SettingsBannerAd> {
  BannerAd? _banner;
  bool _loaded = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadAd());
    }
  }

  Future<void> _loadAd() async {
    if (!mounted || !AdConfig.isSupportedPlatform) return;
    final allowed = await AdService.instance.prepareForAds();
    if (!mounted || !allowed) return;

    final width = (MediaQuery.sizeOf(context).width - 48).floor();
    if (width <= 0) return;
    final size = await AdSize.getLargeAnchoredAdaptiveBannerAdSize(width);
    if (!mounted || size == null) return;

    final adUnitId = AdConfig.settingsBannerId;
    if (adUnitId == null) return;
    final banner = BannerAd(
      adUnitId: adUnitId,
      size: size,
      request: const AdRequest(nonPersonalizedAds: true),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('Settings banner failed to load: ${error.message}');
          ad.dispose();
          if (mounted) setState(() => _loaded = false);
        },
      ),
    );
    _banner = banner;
    try {
      await banner.load();
    } catch (error) {
      debugPrint('Settings banner request failed: $error');
      await banner.dispose();
      if (identical(_banner, banner)) _banner = null;
    }
  }

  @override
  void dispose() {
    unawaited(_banner?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final banner = _banner;
    if (!_loaded || banner == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.lg),
      child: LiquidGlassSurface(
        borderRadius: AppRadius.lg,
        blur: 16,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'ADVERTISEMENT',
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.48),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
            ),
            Center(
              child: SizedBox(
                width: banner.size.width.toDouble(),
                height: banner.size.height.toDouble(),
                child: AdWidget(ad: banner),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
