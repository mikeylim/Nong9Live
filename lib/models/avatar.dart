import 'dart:math';

import 'package:flutter/material.dart';

enum HairStyle {
  bald('Bald'),
  buzz('Buzz'),
  short('Short'),
  flatTop('High-top'),
  afro('Afro'),
  curly('Curly'),
  long('Long'),
  bun('Bun'),
  mohawk('Mohawk');

  const HairStyle(this.label);
  final String label;
}

enum Beard {
  none('None'),
  stubble('Stubble'),
  mustache('Mustache'),
  goatee('Goatee'),
  full('Full');

  const Beard(this.label);
  final String label;
}

enum Face {
  smile('Smile'),
  grin('Grin'),
  focused('Locked in'),
  hype('Hype'),
  happy('Happy');

  const Face(this.label);
  final String label;
}

enum Eyewear {
  none('None'),
  glasses('Glasses'),
  goggles('Goggles');

  const Eyewear(this.label);
  final String label;
}

const skinTones = <Color>[
  Color(0xFFFFE0C7),
  Color(0xFFF5CBA7),
  Color(0xFFE6B48A),
  Color(0xFFD29A6C),
  Color(0xFFB57B4F),
  Color(0xFF94603B),
  Color(0xFF6F4429),
  Color(0xFF4B2C1A),
];

const hairColors = <Color>[
  Color(0xFF1B1B1F),
  Color(0xFF3A2416),
  Color(0xFF6B4226),
  Color(0xFFB07A3E),
  Color(0xFFE3C16F),
  Color(0xFFA63D24),
  Color(0xFF9E9E9E),
  Color(0xFFF2F2F2),
  Color(0xFF3B82F6),
  Color(0xFFEC4899),
];

const accessoryColors = <Color>[
  Color(0xFFFFFFFF),
  Color(0xFF1B1B1F),
  Color(0xFFE53935),
  Color(0xFF1E88E5),
  Color(0xFFFF6B1A),
  Color(0xFF43A047),
  Color(0xFFFDD835),
  Color(0xFF8E24AA),
];

const jerseyColors = <Color>[
  Color(0xFFE53935),
  Color(0xFF1E88E5),
  Color(0xFF1B1B1F),
  Color(0xFFF1F1F1),
  Color(0xFF43A047),
  Color(0xFFFDD835),
  Color(0xFFFF6B1A),
  Color(0xFF8E24AA),
  Color(0xFF283593),
  Color(0xFF00897B),
];

/// A cartoon player avatar, for profiles without a photo.
@immutable
class AvatarSpec {
  const AvatarSpec({
    required this.skin,
    required this.hair,
    required this.hairColor,
    this.face = Face.smile,
    this.beard = Beard.none,
    this.eyewear = Eyewear.none,
    this.headband,
    required this.jersey,
  });

  final int skin;
  final HairStyle hair;
  final int hairColor;
  final Face face;
  final Beard beard;
  final Eyewear eyewear;

  /// Headband color, or null for none.
  final int? headband;
  final int jersey;

  static final _rng = Random();

  factory AvatarSpec.random([Random? random]) {
    final r = random ?? _rng;
    T pick<T>(List<T> items) => items[r.nextInt(items.length)];
    // Natural hair colors most of the time; the fun ones occasionally.
    final hair = r.nextDouble() < 0.9 ? hairColors.take(7).toList() : hairColors;
    return AvatarSpec(
      skin: pick(skinTones).toARGB32(),
      hair: pick(HairStyle.values),
      hairColor: pick(hair).toARGB32(),
      face: pick(Face.values),
      beard: r.nextDouble() < 0.55 ? Beard.none : pick(Beard.values),
      eyewear: r.nextDouble() < 0.8 ? Eyewear.none : pick(Eyewear.values.skip(1).toList()),
      headband: r.nextDouble() < 0.6 ? null : pick(accessoryColors).toARGB32(),
      jersey: pick(jerseyColors).toARGB32(),
    );
  }

  AvatarSpec copyWith({
    int? skin,
    HairStyle? hair,
    int? hairColor,
    Face? face,
    Beard? beard,
    Eyewear? eyewear,
    int? Function()? headband,
    int? jersey,
  }) =>
      AvatarSpec(
        skin: skin ?? this.skin,
        hair: hair ?? this.hair,
        hairColor: hairColor ?? this.hairColor,
        face: face ?? this.face,
        beard: beard ?? this.beard,
        eyewear: eyewear ?? this.eyewear,
        headband: headband != null ? headband() : this.headband,
        jersey: jersey ?? this.jersey,
      );

  Map<String, dynamic> toJson() => {
        'skin': skin,
        'hair': hair.name,
        'hairColor': hairColor,
        'face': face.name,
        'beard': beard.name,
        'eyewear': eyewear.name,
        'headband': headband,
        'jersey': jersey,
      };

  factory AvatarSpec.fromJson(Map<String, dynamic> j) {
    T byName<T extends Enum>(List<T> values, Object? name, T fallback) =>
        values.where((v) => v.name == name).firstOrNull ?? fallback;
    return AvatarSpec(
      skin: (j['skin'] as num?)?.toInt() ?? skinTones[2].toARGB32(),
      hair: byName(HairStyle.values, j['hair'], HairStyle.short),
      hairColor: (j['hairColor'] as num?)?.toInt() ?? hairColors.first.toARGB32(),
      face: byName(Face.values, j['face'], Face.smile),
      beard: byName(Beard.values, j['beard'], Beard.none),
      eyewear: byName(Eyewear.values, j['eyewear'], Eyewear.none),
      headband: (j['headband'] as num?)?.toInt(),
      jersey: (j['jersey'] as num?)?.toInt() ?? jerseyColors.first.toARGB32(),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AvatarSpec &&
      other.skin == skin &&
      other.hair == hair &&
      other.hairColor == hairColor &&
      other.face == face &&
      other.beard == beard &&
      other.eyewear == eyewear &&
      other.headband == headband &&
      other.jersey == jersey;

  @override
  int get hashCode => Object.hash(skin, hair, hairColor, face, beard, eyewear, headband, jersey);
}
