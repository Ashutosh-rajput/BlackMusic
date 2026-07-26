import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  Future<bool> requestMusicPermission() async {
    final audioStatus = await Permission.audio.request();
    if (audioStatus.isGranted || audioStatus.isLimited) {
      return true;
    }

    final storageStatus = await Permission.storage.request();
    if (storageStatus.isGranted || storageStatus.isLimited) {
      return true;
    }

    return false;
  }
}
