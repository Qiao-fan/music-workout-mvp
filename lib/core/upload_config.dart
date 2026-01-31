// Configuration for file uploads - size limits and compression settings.
// Adjust these values to control storage costs.

class UploadConfig {
  UploadConfig._();

  // Max file sizes in bytes
  static const int maxImageSize = 10 * 1024 * 1024; // 10 MB
  static const int maxVideoSize = 100 * 1024 * 1024; // 100 MB
  static const int maxAudioSize = 25 * 1024 * 1024; // 25 MB
  static const int maxPdfSize = 20 * 1024 * 1024; // 20 MB

  static int getMaxSizeForExtension(String ext) {
    final e = ext.toLowerCase();
    if (e == 'jpg' || e == 'jpeg' || e == 'png' || e == 'gif') {
      return maxImageSize;
    }
    if (e == 'mp4' || e == 'mov' || e == 'avi') {
      return maxVideoSize;
    }
    if (e == 'mp3' || e == 'wav' || e == 'm4a') {
      return maxAudioSize;
    }
    if (e == 'pdf') {
      return maxPdfSize;
    }
    return maxImageSize; // default
  }

  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  // Image compression (only for jpg, jpeg, png)
  static const int imageCompressQuality = 85; // 0-100
  static const int imageMaxWidth = 1920;
  static const int imageMaxHeight = 1920;
}
