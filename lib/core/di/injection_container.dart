import 'package:get_it/get_it.dart';
import 'package:pixel_player/data/database/app_database.dart';
import 'package:pixel_player/data/datasources/local/music_local_datasource.dart';
import 'package:pixel_player/data/repositories/music_repository.dart';
import 'package:pixel_player/services/audio_service.dart';
import 'package:pixel_player/services/file_service.dart';
import 'package:pixel_player/services/permission_service.dart';
import 'package:pixel_player/presentation/bloc/player/player_bloc.dart';
import 'package:pixel_player/presentation/bloc/library/library_bloc.dart';

final getIt = GetIt.instance;

Future<void> getItSetup() async {
  // Database
  final db = AppDatabase();
  getIt.registerSingleton<AppDatabase>(db);

  // Data sources
  getIt.registerLazySingleton<MusicLocalDatasource>(
    () => MusicLocalDatasourceImpl(getIt<AppDatabase>()),
  );

  // Repositories
  getIt.registerLazySingleton<MusicRepository>(
    () => MusicRepositoryImpl(getIt<MusicLocalDatasource>()),
  );

  // Services
  getIt.registerLazySingleton<AudioPlayerService>(
    () => AudioPlayerService(),
    dispose: (service) => service.dispose(),
  );
  getIt.registerLazySingleton<FileService>(() => FileService());
  getIt.registerLazySingleton<PermissionService>(() => PermissionService());

  // BLoCs
  getIt.registerLazySingleton<PlayerBloc>(
    () => PlayerBloc(
      audioService: getIt<AudioPlayerService>(),
      repository: getIt<MusicRepository>(),
    ),
    dispose: (bloc) => bloc.close(),
  );

  getIt.registerLazySingleton<LibraryBloc>(
    () => LibraryBloc(
      repository: getIt<MusicRepository>(),
      fileService: getIt<FileService>(),
      permissionService: getIt<PermissionService>(),
    ),
    dispose: (bloc) => bloc.close(),
  );
}
