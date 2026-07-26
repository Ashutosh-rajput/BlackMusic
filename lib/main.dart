import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:audio_session/audio_session.dart';
import 'package:pixel_player/core/di/injection_container.dart';
import 'package:pixel_player/core/theme/app_theme.dart';
import 'package:pixel_player/presentation/bloc/library/library_bloc.dart';
import 'package:pixel_player/presentation/bloc/player/player_bloc.dart';
import 'package:pixel_player/presentation/screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
  } catch (e) {
    debugPrint('Audio session configuration error: $e');
  }

  await getItSetup();

  runApp(const PixelPlayerApp());
}

class PixelPlayerApp extends StatelessWidget {
  const PixelPlayerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<PlayerBloc>(create: (_) => getIt<PlayerBloc>()),
        BlocProvider<LibraryBloc>(create: (_) => getIt<LibraryBloc>()),
      ],
      child: MaterialApp(
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
