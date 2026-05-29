import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppShortcuts {
  static Map<ShortcutActivator, VoidCallback> build({
    VoidCallback? onOpenFile,
    VoidCallback? onSummary,
    VoidCallback? onQuestions,
    VoidCallback? onExplanation,
    VoidCallback? onChat,
    VoidCallback? onHistory,
    VoidCallback? onProfile,
    VoidCallback? onSettings,
    VoidCallback? onBack,
  }) {
    return {
      const SingleActivator(LogicalKeyboardKey.keyO, control: true):
          onOpenFile ?? () {},
      const SingleActivator(LogicalKeyboardKey.keyS, control: true):
          onSummary ?? () {},
      const SingleActivator(LogicalKeyboardKey.keyQ, control: true):
          onQuestions ?? () {},
      const SingleActivator(LogicalKeyboardKey.keyE, control: true):
          onExplanation ?? () {},
      const SingleActivator(LogicalKeyboardKey.keyC, control: true):
          onChat ?? () {},
      const SingleActivator(LogicalKeyboardKey.keyH, control: true):
          onHistory ?? () {},
      const SingleActivator(LogicalKeyboardKey.keyP, control: true):
          onProfile ?? () {},
      const SingleActivator(LogicalKeyboardKey.comma, control: true):
          onSettings ?? () {},
      const SingleActivator(LogicalKeyboardKey.escape):
          onBack ?? () {},
    };
  }
}
