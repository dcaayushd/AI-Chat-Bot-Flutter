import 'package:flutter/animation.dart';

abstract final class AppMotion {
  static const fast = Duration(milliseconds: 180);
  static const regular = Duration(milliseconds: 220);
  static const scroll = Duration(milliseconds: 240);
  static const curve = Curves.easeOutCubic;
}
