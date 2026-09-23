import 'package:equatable/equatable.dart';

class YouTubeVideoItem extends Equatable {
  final String id;
  final String title;
  final String author;
  final Duration duration;
  final String thumbnailUrl;
  final String url;
  final String quality;

  const YouTubeVideoItem({
    required this.id,
    required this.title,
    required this.author,
    required this.duration,
    required this.thumbnailUrl,
    required this.url,
    this.quality = '128 kbps',
  });

  @override
  List<Object?> get props => [id, title, author, duration, thumbnailUrl, url, quality];
}
