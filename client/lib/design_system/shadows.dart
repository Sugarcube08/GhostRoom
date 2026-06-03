import 'package:flutter/material.dart';

class AppShadows {
  static const BoxShadow soft = BoxShadow(
    color: Color(0x3D000000), // black with opacity 0.24
    blurRadius: 16.0,
    offset: Offset(0, 8),
  );

  static const BoxShadow ambient = BoxShadow(
    color: Color(0x1F000000),
    blurRadius: 32.0,
    offset: Offset(0, 16),
  );
}
