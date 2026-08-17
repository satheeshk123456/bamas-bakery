import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../app_theme.dart';
import 'home_screen.dart';

/// Plays the shop's splash video full-screen on launch, then hands off to
/// the home screen. If the video can't load for any reason (missing asset,
/// unsupported codec on an old device, etc.) this falls back to the plain
/// logo splash instead of leaving the user on a blank screen.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  VideoPlayerController? _controller;
  bool _videoFailed = false;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();

    final controller = VideoPlayerController.asset('assets/videos/splash.mp4');
    _controller = controller;
    controller.initialize().then((_) {
      if (!mounted) return;
      setState(() {});
      controller.setLooping(false);
      // On web, browsers (Chrome included) block autoplay for any video
      // with sound unless it starts muted — without muting there, the
      // video just sits frozen on its first frame. On the real app (APK/
      // iOS) there's no such restriction, so play it with sound like a
      // normal splash video.
      if (kIsWeb) controller.setVolume(0);
      controller.play();
      controller.addListener(_checkVideoEnd);

      // Safety net, timed off the video's OWN duration (not a fixed
      // guess) so it can only fire after the full clip has had time to
      // play out — it never cuts playback short, it just guarantees we
      // still move on if the "finished" listener update is ever missed.
      Future.delayed(
        controller.value.duration + const Duration(seconds: 2),
        _goHome,
      );
    }).catchError((_) {
      // Asset missing / codec unsupported — nothing to wait for, so fall
      // back to the logo splash right away.
      if (!mounted) return;
      setState(() => _videoFailed = true);
      Future.delayed(const Duration(milliseconds: 1300), _goHome);
    });
  }

  void _checkVideoEnd() {
    final value = _controller?.value;
    if (value == null || !value.isInitialized) return;
    // Require BOTH: playback has actually stopped, and the position has
    // reached the end. Checking position alone can fire a hair before the
    // last frame has actually been shown, which is what was cutting the
    // video short.
    final reachedEnd = value.duration.inMilliseconds > 0 &&
        value.position >= value.duration - const Duration(milliseconds: 50);
    if (!value.isPlaying && reachedEnd) {
      _goHome();
    }
  }

  void _goHome() {
    if (_navigated || !mounted) return;
    _navigated = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  @override
  void dispose() {
    _controller?.removeListener(_checkVideoEnd);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final ready = controller != null && controller.value.isInitialized;

    return Scaffold(
      // White background (not full-bleed black) so the video reads as a
      // smaller, centered piece of the splash rather than filling the
      // whole screen.
      backgroundColor: Colors.white,
      body: Center(
        child: (ready && !_videoFailed)
            ? ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 220),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: AspectRatio(
                    aspectRatio:
                        controller.value.size.width / controller.value.size.height,
                    child: VideoPlayer(controller),
                  ),
                ),
              )
            : const _LogoFallback(),
      ),
    );
  }
}

/// The original static logo splash, used only while the video initializes
/// (briefly) or if it fails to load at all.
class _LogoFallback extends StatelessWidget {
  const _LogoFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Image.asset(
                AppBranding.logoAsset,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Text(
                  AppBranding.shopName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppBranding.primary,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            if (AppBranding.tagline.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                AppBranding.tagline,
                style: const TextStyle(color: AppBranding.textMuted, fontSize: 13),
              ),
            ],
            const SizedBox(height: 32),
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: AppBranding.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
