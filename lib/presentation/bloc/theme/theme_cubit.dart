import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:pixel_player/services/settings_service.dart';

class ThemeSettingsState extends Equatable {
  final String themeMode;
  final int accentColorIndex;
  final bool amoledBlackMode;
  final String fontSize;
  final String albumArtSize;

  const ThemeSettingsState({
    required this.themeMode,
    required this.accentColorIndex,
    required this.amoledBlackMode,
    required this.fontSize,
    required this.albumArtSize,
  });

  ThemeSettingsState copyWith({
    String? themeMode,
    int? accentColorIndex,
    bool? amoledBlackMode,
    String? fontSize,
    String? albumArtSize,
  }) {
    return ThemeSettingsState(
      themeMode: themeMode ?? this.themeMode,
      accentColorIndex: accentColorIndex ?? this.accentColorIndex,
      amoledBlackMode: amoledBlackMode ?? this.amoledBlackMode,
      fontSize: fontSize ?? this.fontSize,
      albumArtSize: albumArtSize ?? this.albumArtSize,
    );
  }

  @override
  List<Object?> get props => [
        themeMode,
        accentColorIndex,
        amoledBlackMode,
        fontSize,
        albumArtSize,
      ];
}

class ThemeCubit extends Cubit<ThemeSettingsState> {
  final SettingsService _settingsService;

  ThemeCubit(this._settingsService)
      : super(ThemeSettingsState(
          themeMode: _settingsService.themeMode,
          accentColorIndex: _settingsService.accentColorIndex,
          amoledBlackMode: _settingsService.amoledBlackMode,
          fontSize: _settingsService.fontSize,
          albumArtSize: _settingsService.albumArtSize,
        ));

  void setThemeMode(String mode) {
    _settingsService.setThemeMode(mode);
    emit(state.copyWith(themeMode: mode));
  }

  void setAccentColorIndex(int index) {
    _settingsService.setAccentColorIndex(index);
    emit(state.copyWith(accentColorIndex: index));
  }

  void setAmoledBlackMode(bool enabled) {
    _settingsService.setAmoledBlackMode(enabled);
    emit(state.copyWith(amoledBlackMode: enabled));
  }

  void setFontSize(String size) {
    _settingsService.setFontSize(size);
    emit(state.copyWith(fontSize: size));
  }

  void setAlbumArtSize(String size) {
    _settingsService.setAlbumArtSize(size);
    emit(state.copyWith(albumArtSize: size));
  }
}
