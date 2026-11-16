/// One library root in the browser's left column (a plugged USB stick, the
/// local disk, …).
class LibEntry {
  const LibEntry(this.name);

  final String name;
}

/// One playlist (or saved folder) below a library.
class ListEntry {
  const ListEntry(this.name);

  final String name;
}

/// One row of the tracks pane.
class TrackRow {
  const TrackRow({
    required this.title,
    required this.artist,
    required this.bpm,
    required this.key,
    required this.seconds,
  });

  final String title;
  final String artist;
  final double bpm;
  final String key;
  final int seconds;
}
