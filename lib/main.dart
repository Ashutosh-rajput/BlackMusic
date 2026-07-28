import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:audio_session/audio_session.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:pixel_player/core/di/injection_container.dart';
import 'package:pixel_player/core/theme/app_theme.dart';
import 'package:pixel_player/presentation/bloc/library/library_bloc.dart';
import 'package:pixel_player/presentation/bloc/player/player_bloc.dart';
import 'package:pixel_player/presentation/screens/splash_screen.dart';
import 'package:pixel_player/presentation/widgets/download_dialog.dart';

import 'package:just_audio_background/just_audio_background.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.pixelplayer.audio',
      androidNotificationChannelName: 'Audio Playback',
      androidNotificationOngoing: true,
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

  await getItSetup();

  runApp(const PixelPlayerApp());
}

class PixelPlayerApp extends StatefulWidget {
  const PixelPlayerApp({super.key});

  @override
  State<PixelPlayerApp> createState() => _PixelPlayerAppState();
}

class _PixelPlayerAppState extends State<PixelPlayerApp> {
  StreamSubscription? _intentDataStreamSubscription;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _initShareIntentListener();
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
    final context = _navigatorKey.currentContext;
    if (context != null && text.trim().isNotEmpty) {
      DownloadDialog.show(context, initialUrl: text);
    }
  }

  @override
  void dispose() {
    _intentDataStreamSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<PlayerBloc>(create: (_) => getIt<PlayerBloc>()),
        BlocProvider<LibraryBloc>(create: (_) => getIt<LibraryBloc>()),
      ],
      child: MaterialApp(
        navigatorKey: _navigatorKey,
        title: 'PixelPlayer',
        debugShowCheckedModeBanner: false,
        theme: lightTheme,
        darkTheme: darkTheme,
        themeMode: ThemeMode.dark,
        home: const SplashScreen(),
      ),
    );
  }
}
