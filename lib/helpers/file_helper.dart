import 'dart:io';

class FileHelper {
  static late Directory dir;
  static void createFolderInMedia() async {
    dir = Directory('/storage/emulated/0/Android/media/com.buyp.selldroid20');

    if (!dir.existsSync()) dir.createSync(recursive: true);

    // Handle permission denied
    /*  throw Exception("Storage permission not granted"); */
  }
}
