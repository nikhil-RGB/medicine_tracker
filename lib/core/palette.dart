import 'package:flutter/material.dart';

/// Stable color palette assigned to conditions so each gets a consistent chip
/// across Today and the calendar.
const List<int> kConditionPalette = [
  0xFF6750A4, // purple
  0xFF1565C0, // blue
  0xFF2E7D32, // green
  0xFFC62828, // red
  0xFFEF6C00, // orange
  0xFF00838F, // teal
  0xFFAD1457, // pink
  0xFF4E342E, // brown
  0xFF455A64, // blue-grey
  0xFF5D4037, // deep brown
  0xFF283593, // indigo
  0xFF00695C, // dark teal
];

int conditionColorSeedFor(int index) => kConditionPalette[index % kConditionPalette.length];

Color colorFromSeed(int seed) => Color(seed);
