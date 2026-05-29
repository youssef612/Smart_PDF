import 'package:flutter/material.dart';

class Responsive {
  static double maxWidth(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    if (w < 600)  return w;
    if (w < 1200) return 700;
    return 900;
  }

  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < 600;

  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= 600 &&
      MediaQuery.of(context).size.width < 1200;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= 1200;

  static EdgeInsets pagePadding(BuildContext context) {
    if (isMobile(context)) return const EdgeInsets.all(16);
    if (isTablet(context)) return const EdgeInsets.all(24);
    return const EdgeInsets.all(32);
  }

  static double fontSize(BuildContext context, double mobile) {
    if (isDesktop(context)) return mobile * 1.15;
    if (isTablet(context))  return mobile * 1.08;
    return mobile;
  }
}