import 'dart:async';
import 'dart:io';

import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../timer/timer_engine.dart';

// TODO: trocar pelos IDs reais após publicar o app e AdMob aprovar.
// IDs reais: ca-app-pub-7328881363835651/1901369050 (ambas plataformas)
const _kInterstitialAndroid = 'ca-app-pub-3940256099942544/1033173712';
const _kInterstitialIos     = 'ca-app-pub-3940256099942544/4411468910';

/// Escuta os streams do engine e exibe interstitial no fim de sessão.
/// Não conhece UI — segue o mesmo padrão de desacoplamento do AudioService.
class AdService {
  AdService(this._events, this._snapshots);

  final Stream<TimerEvent> _events;
  final Stream<TimerSnapshot> _snapshots;

  static const _minSession = Duration(seconds: 30);

  InterstitialAd? _ad;
  Duration _elapsed = Duration.zero;
  bool _shown = false;
  StreamSubscription<TimerEvent>? _eventSub;
  StreamSubscription<TimerSnapshot>? _snapSub;

  void init() {
    _snapSub = _snapshots.listen((s) => _elapsed = s.elapsedTotal);
    _eventSub = _events.listen(_onEvent);
    _loadAd();
  }

  void _onEvent(TimerEvent _) {
    // Auto-trigger removido — WorkoutCompleteScreen chama showIfEligible()
    // após montar, garantindo que a tela aparece antes do interstitial.
  }

  /// Exibe o interstitial se a sessão foi longa o suficiente e o ad ainda
  /// não foi mostrado. Deve ser chamado pela tela de conclusão após montar.
  void showIfEligible() {
    if (!_shown && _elapsed >= _minSession) _showAd();
  }

  Future<void> _loadAd() async {
    final unitId = Platform.isIOS ? _kInterstitialIos : _kInterstitialAndroid;
    try {
      await InterstitialAd.load(
        adUnitId: unitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            _ad = ad;
            _ad!.fullScreenContentCallback = FullScreenContentCallback(
              onAdDismissedFullScreenContent: (ad) => ad.dispose(),
              onAdFailedToShowFullScreenContent: (ad, _) => ad.dispose(),
            );
          },
          onAdFailedToLoad: (_) => _ad = null,
        ),
      );
    } catch (_) {
      // Ad failure must never crash the timer.
    }
  }

  void _showAd() {
    if (_ad == null) return;
    _shown = true;
    _ad!.show();
    _ad = null;
  }

  void dispose() {
    _eventSub?.cancel();
    _snapSub?.cancel();
    _ad?.dispose();
    _ad = null;
  }
}
