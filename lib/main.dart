import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:audio_session/audio_session.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:pixel_player/core/di/injection_container.dart';
import 'package:pixel_player/core/theme/app_theme.dart';
import 'package:pixel_player/presentation/bloc/library/library_bloc.dart';
import 'package:pixel_player/presentation/bloc/player/player_bloc.dart';
import 'package:pixel_player/presentation/bloc/theme/theme_cubit.dart';
import 'package:pixel_player/presentation/screens/splash_screen.dart';
import 'package:pixel_player/presentation/widgets/download_queue_sheet.dart';
import 'package:pixel_player/presentation/widgets/download_queue_snackbar.dart';
import 'package:pixel_player/services/download_notification_service.dart';
import 'package:pixel_player/services/download_service.dart';
import 'package:pixel_player/services/audio_service.dart';

import 'package:permission_handler/permission_handler.dart';
import 'package:just_audio_background/just_audio_background.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.muskmelon.blackmusic.playback',
      androidNotificationChannelName: 'Audio Playback',
      androidNotificationChannelDescription:
          'Controls and track details for music currently playing',
      androidNotificationOngoing: false,
      androidNotificationIcon: 'mipmap/ic_launcher',
    );
    debugPrint("Background initialized");
  } catch (e) {
    debugPrint('JustAudioBackground init error: $e');
  }

  try {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
  } catch (e) {
    debugPrint('Audio session configuration error: $e');
  }

  try {
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }
  } catch (e) {
    debugPrint('Notification permission error: $e');
  }

  await getItSetup();
  try {
    await DownloadNotificationService().init();
  } catch (e) {
    debugPrint('DownloadNotificationService init error: $e');
  }

  runApp(const PixelPlayerApp());
}

class PixelPlayerApp extends StatefulWidget {
  const PixelPlayerApp({super.key});

  @override
  State<PixelPlayerApp> createState() => _PixelPlayerAppState();
}

class _PixelPlayerAppState extends State<PixelPlayerApp> with WidgetsBindingObserver {
  StreamSubscription? _intentDataStreamSubscription;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initShareIntentListener();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      try {
        getIt<AudioPlayerService>().stop();
      } catch (e) {
        debugPrint('Error stopping player on app detach: $e');
      }
    }
  }

  void _initShareIntentListener() {
    // For sharing text/URLs while app is in memory
    _intentDataStreamSubscription = ReceiveSharingIntent.instance.getMediaStream().listen((value) {
      if (value.isNotEmpty) {
        final sharedText = value.first.path;
        _handleSharedUrl(sharedText);
      }
    }, onError: (err) {
      debugPrint("getIntentDataStream error: $err");
    });

    // For sharing text/URLs when app is closed / launched via share
    ReceiveSharingIntent.instance.getInitialMedia().then((value) {
      if (value.isNotEmpty) {
        final sharedText = value.first.path;
        _handleSharedUrl(sharedText);
      }
    });
  }

  void _handleSharedUrl(String text) {
    final url = text.trim();
    if (url.isEmpty) return;

    // Enqueue immediately in the background — sharing a song must never bring
    // the app UI to the foreground. Progress/completion are surfaced via
    // DownloadNotificationService; this snackbar is just a same-instant nod
    // for when the app already happens to be visible.
    getIt<DownloadService>().enqueueDownload(url: url, fromShare: true);

    final context = _navigatorKey.currentContext;
    if (context != null && context.mounted) {
      showDownloadQueuedSnackBar(
        context,
        title: url,
        onViewQueue: () {
          if (context.mounted) {
            DownloadQueueSheet.show(context);
          }
        },
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _intentDataStreamSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<ThemeCubit>(create: (_) => getIt<ThemeCubit>()),
        BlocProvider<PlayerBloc>(create: (_) => getIt<PlayerBloc>()),
        BlocProvider<LibraryBloc>(create: (_) => getIt<LibraryBloc>()),
      ],
      child: BlocBuilder<ThemeCubit, ThemeSettingsState>(
        builder: (context, themeState) {
          ThemeMode mode = ThemeMode.system;
          if (themeState.themeMode == 'Light') mode = ThemeMode.light;
          if (themeState.themeMode == 'Dark') mode = ThemeMode.dark;

          final light = AppTheme.buildTheme(
            brightness: Brightness.light,
            accentIndex: themeState.accentColorIndex,
            isAmoled: false,
          );

          final dark = AppTheme.buildTheme(
            brightness: Brightness.dark,
            accentIndex: themeState.accentColorIndex,
            isAmoled: themeState.amoledBlackMode,
          );

          return MaterialApp(
            navigatorKey: _navigatorKey,
            title: 'BlackMusic',
            debugShowCheckedModeBanner: false,
            theme: light,
            darkTheme: dark,
            themeMode: mode,
            builder: (context, child) {
              return MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(themeState.fontScale),
                ),
                child: child!,
              );
            },
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}
