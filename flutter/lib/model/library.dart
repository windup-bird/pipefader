/// One library root in the browser's left column (a plugged USB stick, the
/// local disk, …).
class LibEntry {
  const LibEntry(this.name, {this.id = -1});

  final String name;
  final int id;
}

/// One playlist (or saved folder) below a library.
class ListEntry {
  const ListEntry(this.name, {this.id = -1, this.sourceId = -1});

  final String name;
  final int id;
  final int sourceId;
}

/// One row of the tracks pane.
class TrackRow {
  const TrackRow({
    required this.title,
    required this.artist,
    required this.bpm,
    required this.key,
    required this.seconds,
    this.trackId = -1,
    this.locationId = -1,
  });

  final String title;
  final String artist;
  final double bpm;
  final String key;
  final int seconds;
  final int trackId;
  final int locationId;
}
