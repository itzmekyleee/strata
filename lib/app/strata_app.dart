import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import 'router.dart';
import 'theme/strata_palette.dart';
import 'theme/strata_theme.dart';
import 'theme/text_scale.dart';
import 'theme/theme_variant.dart';
import '../core/widgets/pointer_activity.dart';
import '../core/widgets/toasts.dart';
import '../providers/core_providers.dart';
import '../providers/notes_providers.dart';

class StrataApp extends ConsumerStatefulWidget {
  const StrataApp({super.key});

  @override
  ConsumerState<StrataApp> createState() => _StrataAppState();
}

class _StrataAppState extends ConsumerState<StrataApp>
    with WidgetsBindingObserver {
  StreamSubscription<List<SharedMediaFile>>? _sharedSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Listen for shared images from other apps when the editor is not open.
    _sharedSub = ReceiveSharingIntent.instance.getMediaStream().listen(
      _handleSharedMedia,
      onError: (err) => debugPrint('receive_sharing_intent error: $err'),
    );
    // Handle intent that launched the app (cold start).
    ReceiveSharingIntent.instance.getInitialMedia().then(_handleSharedMedia);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sharedSub?.cancel();
    super.dispose();
  }

  /// Pointer events are not guaranteed to arrive in pairs across lifecycle
  /// changes; recount from zero whenever the app is backgrounded/foregrounded
  /// so the stuck-drag watchdog is never disabled by a phantom pointer.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.resumed) {
      PointerActivity.reset();
    }
  }

  void _handleSharedMedia(List<SharedMediaFile> files) {
    final imagePaths = files.map((f) => f.path).toList();
    if (imagePaths.isNotEmpty) {
      ref.read(pendingSharedImagesProvider.notifier).add(imagePaths);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Load persisted variant on first build, then watch for changes.
    ref.read(themeVariantProvider.notifier).load();
    ref.read(textScaleProvider.notifier).load();
    ref.read(noteSortProvider.notifier).load();
    final variant = ref.watch(themeVariantProvider);
    final textScale = ref.watch(textScaleProvider);
    StrataPalette.applyVariant(variant);

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(textScale.factor),
      ),
      child: PointerActivity.track(
        child: MaterialApp.router(
          title: 'Strata',
          debugShowCheckedModeBanner: false,
          theme: StrataTheme.build(Brightness.light),
          darkTheme: StrataTheme.build(Brightness.dark),
          themeMode: variant.isDark ? ThemeMode.dark : ThemeMode.light,
          routerConfig: ref.watch(routerProvider),
          builder: (context, child) => ToastOverlayHost(
            child: ScrollConfiguration(
              behavior: const _NoGlowScroll(),
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
  }
}

class _NoGlowScroll extends ScrollBehavior {
  const _NoGlowScroll();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;
}