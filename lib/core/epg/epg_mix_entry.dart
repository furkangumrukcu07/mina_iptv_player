import '../../domain/entities/channel.dart';
import '../../domain/entities/epg_entities.dart';
import 'epg_mix_category.dart';

/// Sıradaki yayın: EPG programı + canlı kanal.
class EpgMixEntry {
  const EpgMixEntry({
    required this.category,
    required this.programme,
    required this.channel,
  });

  final EpgMixCategory category;
  final EpgProgramme programme;
  final Channel channel;
}
