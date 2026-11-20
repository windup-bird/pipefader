import 'package:pipefader_gui/model/deck.dart';
import 'package:pipefader_gui/model/library.dart';
import 'package:pipefader_gui/model/peaks.dart';

/// The decks the sketch renders. The first two are the pair the desk starts
/// with; the other two are the alternate slots in a four-deck rig.
List<DeckView> buildDecks() {
  const rate = 44100;
  return [
    DeckView(
      artist: 'Vera Lumen',
      title: 'Slowburn',
      album: 'Ember',
      key: '8A',
      bpm: 128,
      sampleRate: rate,
      totalFrames: 312 * rate,
      firstBeat: (0.32 * rate).round(),
      peaks: buildPeaks(seed: 7, seconds: 312, bpm: 128),
      coverSeed: 3,
    ),
    DeckView(
      artist: 'Kade Moro',
      title: 'Cold Chamber',
      album: 'Depth',
      key: '11B',
      bpm: 132,
      sampleRate: rate,
      totalFrames: 407 * rate,
      firstBeat: (0.61 * rate).round(),
      peaks: buildPeaks(seed: 19, seconds: 407, bpm: 132),
      coverSeed: 11,
    ),
    DeckView(
      artist: 'Mera Sato',
      title: 'Hollow Pulse',
      album: 'Ground',
      key: '9B',
      bpm: 130,
      sampleRate: rate,
      totalFrames: 388 * rate,
      firstBeat: (0.44 * rate).round(),
      peaks: buildPeaks(seed: 31, seconds: 388, bpm: 130),
      coverSeed: 5,
    ),
    DeckView(
      artist: 'Otto Rell',
      title: 'Nightshift',
      album: 'Afterimage',
      key: '4A',
      bpm: 126,
      sampleRate: rate,
      totalFrames: 341 * rate,
      firstBeat: (0.18 * rate).round(),
      peaks: buildPeaks(seed: 43, seconds: 341, bpm: 126),
      coverSeed: 8,
    ),
  ];
}

const libraries = <LibEntry>[LibEntry('USB'), LibEntry('Local')];

const playlists = <ListEntry>[
  ListEntry('All Tracks'),
  ListEntry('Warmup'),
  ListEntry('Peak Time'),
  ListEntry('Closing'),
  ListEntry('Unreleased'),
];

const tracks = <TrackRow>[
  TrackRow(
    title: 'Cold Chamber',
    artist: 'Kade Moro',
    bpm: 132,
    key: '11B',
    seconds: 407,
  ),
  TrackRow(
    title: 'Slowburn',
    artist: 'Vera Lumen',
    bpm: 128,
    key: '8A',
    seconds: 312,
  ),
  TrackRow(
    title: 'Iron Yard',
    artist: 'Nils Achter',
    bpm: 134,
    key: '5A',
    seconds: 356,
  ),
  TrackRow(
    title: 'Hollow Pulse',
    artist: 'Mera Sato',
    bpm: 130,
    key: '9B',
    seconds: 388,
  ),
  TrackRow(
    title: 'Nightshift',
    artist: 'Otto Rell',
    bpm: 126,
    key: '4A',
    seconds: 341,
  ),
  TrackRow(
    title: 'Static Bloom',
    artist: 'Iva Kern',
    bpm: 128,
    key: '7A',
    seconds: 329,
  ),
  TrackRow(
    title: 'Concrete Garden',
    artist: 'Runa Vos',
    bpm: 135,
    key: '1B',
    seconds: 375,
  ),
  TrackRow(
    title: 'Low Orbit',
    artist: 'Senne Dael',
    bpm: 131,
    key: '12A',
    seconds: 362,
  ),
  TrackRow(
    title: 'Copper Line',
    artist: 'Ansel Greb',
    bpm: 129,
    key: '6B',
    seconds: 318,
  ),
  TrackRow(
    title: 'Rift',
    artist: 'Kade Moro',
    bpm: 133,
    key: '3A',
    seconds: 401,
  ),
  TrackRow(
    title: 'Pale Signal',
    artist: 'Vera Lumen',
    bpm: 127,
    key: '10B',
    seconds: 296,
  ),
  TrackRow(
    title: 'Ground Loop',
    artist: 'Mera Sato',
    bpm: 136,
    key: '2A',
    seconds: 349,
  ),
  TrackRow(
    title: 'Ash Drift',
    artist: 'Nils Achter',
    bpm: 125,
    key: '8B',
    seconds: 333,
  ),
  TrackRow(
    title: 'Hex Room',
    artist: 'Iva Kern',
    bpm: 130,
    key: '11A',
    seconds: 367,
  ),
  TrackRow(
    title: 'Afterimage',
    artist: 'Otto Rell',
    bpm: 132,
    key: '5B',
    seconds: 392,
  ),
  TrackRow(
    title: 'Deep Field',
    artist: 'Runa Vos',
    bpm: 124,
    key: '9A',
    seconds: 354,
  ),
];
