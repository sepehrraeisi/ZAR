import 'dart:math';

/// Collision-resistant opaque ID generator for local-first records.
///
/// A timestamp alone can collide when two records are created within the same
/// microsecond (rapid programmatic writes), so a random suffix is always
/// appended. IDs carry no ordering guarantee and are never parsed back.
String zarNewId(String prefix) {
  final now = DateTime.now().microsecondsSinceEpoch;
  final random = Random.secure().nextInt(0x10000);
  return '$prefix-$now-${random.toRadixString(16).padLeft(4, '0')}';
}
