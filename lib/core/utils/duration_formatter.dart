String formatDuration(Duration duration) {
  String twoDigits(int n) => n.toString().padLeft(2, '0');
  final minutes = twoDigits(duration.inMinutes.remainder(60));
  final seconds = twoDigits(duration.inSeconds.remainder(60));
  if (duration.inHours > 0) {
    return '${duration.inHours}:$minutes:$seconds';
  }
  return '$minutes:$seconds';
}
