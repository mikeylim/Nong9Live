import 'package:flutter/material.dart';

import 'avatar.dart';

enum Position {
  guard('G', 'Guard'),
  forward('F', 'Forward'),
  center('C', 'Center');

  const Position(this.short, this.label);
  final String short;
  final String label;
}

/// The six attributes shown on the player card radar (1..10 each).
enum Attribute {
  shooting('Shooting', 'SHT'),
  finishing('Finishing', 'FIN'),
  playmaking('Playmaking', 'PLY'),
  defense('Defense', 'DEF'),
  rebounding('Rebounding', 'REB'),
  athleticism('Athleticism', 'ATH');

  const Attribute(this.label, this.short);
  final String label;
  final String short;
}

const strengthPresets = <String>[
  '3PT shooting',
  'Mid-range',
  'Finishing',
  'Post moves',
  'Ball handling',
  'Passing',
  'Court vision',
  'Rebounding',
  'Perimeter D',
  'Rim protection',
  'Speed',
  'Hustle',
  'Free throws',
  'Basketball IQ',
  'Leadership',
  'Stamina',
  'Off-ball movement',
  'Left hand',
  'Trash talk',
];

const avatarColors = <Color>[
  Color(0xFFFF6B1A),
  Color(0xFFEF4444),
  Color(0xFFEC4899),
  Color(0xFFA855F7),
  Color(0xFF6366F1),
  Color(0xFF3B82F6),
  Color(0xFF06B6D4),
  Color(0xFF14B8A6),
  Color(0xFF22C55E),
  Color(0xFF84CC16),
  Color(0xFFEAB308),
  Color(0xFF78716C),
];

class Player {
  Player({
    required this.id,
    required this.name,
    this.nickname,
    this.jerseyNumber,
    Set<Position>? positions,
    this.heightCm,
    this.weightKg,
    this.hand,
    List<String>? strengths,
    List<String>? weaknesses,
    Map<Attribute, int>? ratings,
    this.bio,
    this.photoPath,
    this.avatar,
    int? colorValue,
    this.archived = false,
    DateTime? createdAt,
  })  : positions = positions ?? <Position>{},
        strengths = strengths ?? <String>[],
        weaknesses = weaknesses ?? <String>[],
        ratings = ratings ?? {for (final a in Attribute.values) a: 5},
        colorValue = colorValue ?? avatarColors.first.toARGB32(),
        createdAt = createdAt ?? DateTime.now();

  final String id;
  String name;
  String? nickname;
  int? jerseyNumber;
  Set<Position> positions;
  double? heightCm;
  double? weightKg;

  /// 'R' or 'L' (shooting hand).
  String? hand;
  List<String> strengths;
  List<String> weaknesses;
  Map<Attribute, int> ratings;
  String? bio;
  String? photoPath;

  /// Custom cartoon avatar, shown when there's no photo.
  AvatarSpec? avatar;
  int colorValue;
  bool archived;
  final DateTime createdAt;

  Color get color => Color(colorValue);

  /// Overall rating on a 2K-style 40..99 scale, from the 1..10 attributes.
  int get overall {
    final avg = Attribute.values
            .map((a) => ratings[a] ?? 5)
            .fold<int>(0, (s, v) => s + v) /
        Attribute.values.length;
    return (40 + (avg - 1) / 9 * 59).round().clamp(40, 99);
  }

  /// Raw strength used by the team balancer.
  double get strength =>
      Attribute.values.map((a) => ratings[a] ?? 5).fold<int>(0, (s, v) => s + v) /
      Attribute.values.length;

  String get displayName => nickname?.isNotEmpty == true ? nickname! : name;

  String get firstName => name.trim().split(RegExp(r'\s+')).first;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.take(2).toString().toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first).toUpperCase();
  }

  String get positionLabel {
    if (positions.isEmpty) return '';
    final sorted = positions.toList()..sort((a, b) => a.index.compareTo(b.index));
    return sorted.map((p) => p.short).join('/');
  }

  Position? get primaryPosition {
    if (positions.isEmpty) return null;
    final sorted = positions.toList()..sort((a, b) => a.index.compareTo(b.index));
    return sorted.first;
  }

  Player copy() => Player.fromJson(toJson());

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'nickname': nickname,
        'jerseyNumber': jerseyNumber,
        'positions': positions.map((p) => p.name).toList(),
        'heightCm': heightCm,
        'weightKg': weightKg,
        'hand': hand,
        'strengths': strengths,
        'weaknesses': weaknesses,
        'ratings': {for (final e in ratings.entries) e.key.name: e.value},
        'bio': bio,
        'photoPath': photoPath,
        if (avatar != null) 'avatar': avatar!.toJson(),
        'colorValue': colorValue,
        'archived': archived,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Player.fromJson(Map<String, dynamic> j) {
    final ratingsJson = (j['ratings'] as Map?)?.cast<String, dynamic>() ?? {};
    return Player(
      id: j['id'] as String,
      name: j['name'] as String? ?? 'Player',
      nickname: j['nickname'] as String?,
      jerseyNumber: (j['jerseyNumber'] as num?)?.toInt(),
      positions: ((j['positions'] as List?) ?? [])
          .map((p) => Position.values.where((v) => v.name == p).firstOrNull)
          .whereType<Position>()
          .toSet(),
      heightCm: (j['heightCm'] as num?)?.toDouble(),
      weightKg: (j['weightKg'] as num?)?.toDouble(),
      hand: j['hand'] as String?,
      strengths: ((j['strengths'] as List?) ?? []).cast<String>(),
      weaknesses: ((j['weaknesses'] as List?) ?? []).cast<String>(),
      ratings: {
        for (final a in Attribute.values) a: ((ratingsJson[a.name] as num?)?.toInt() ?? 5).clamp(1, 10),
      },
      bio: j['bio'] as String?,
      photoPath: j['photoPath'] as String?,
      avatar: j['avatar'] is Map ? AvatarSpec.fromJson((j['avatar'] as Map).cast<String, dynamic>()) : null,
      colorValue: (j['colorValue'] as num?)?.toInt(),
      archived: j['archived'] as bool? ?? false,
      createdAt: DateTime.tryParse(j['createdAt'] as String? ?? ''),
    );
  }
}
