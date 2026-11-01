import 'package:flutter/material.dart';

import '../drawing_controller.dart';
import '../models.dart';
import 'tool_widgets.dart';

/// Bottom panel: tools and brush sizes on top, colors (or stamps) below.
class ToolPanel extends StatelessWidget {
  const ToolPanel({super.key, required this.controller});

  final DrawingController controller;

  static const double _cornerRadius = 28;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(_cornerRadius)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _scrollRow(_toolRow()),
          const SizedBox(height: 8),
          _scrollRow(c.tool == Tool.stamp ? _stampRow() : _colorRow()),
        ],
      ),
    );
  }

  Widget _scrollRow(Widget row) =>
      SingleChildScrollView(scrollDirection: Axis.horizontal, child: row);

  Widget _toolButton(String emoji, String label, Tool tool) => ToolButton(
        emoji: emoji,
        label: label,
        selected: controller.tool == tool,
        onTap: () => controller.setTool(tool),
      );

  Widget _toolRow() {
    final c = controller;
    return Row(
      children: [
        _toolButton('🖌️', 'Draw', Tool.brush),
        _toolButton('🧽', 'Erase', Tool.eraser),
        _toolButton(c.stamp, 'Stamp', Tool.stamp),
        if (c.page != null) _toolButton('🪣', 'Fill', Tool.fill),
        const SizedBox(width: 12),
        for (final size in kBrushSizes)
          SizeDot(
            size: size,
            selected: c.brushSize == size,
            onTap: () => c.setBrushSize(size),
          ),
      ],
    );
  }

  Widget _colorRow() {
    final c = controller;
    return Row(
      children: [
        RainbowDot(selected: c.rainbow, onTap: c.setRainbow),
        for (final color in kPalette)
          ColorDot(
            color: color,
            selected: !c.rainbow && c.color == color,
            onTap: () => c.setColor(color),
          ),
      ],
    );
  }

  Widget _stampRow() {
    final c = controller;
    return Row(
      children: [
        for (final emoji in kStamps)
          StampChoice(
            emoji: emoji,
            selected: c.stamp == emoji,
            onTap: () => c.setStamp(emoji),
          ),
      ],
    );
  }
}
