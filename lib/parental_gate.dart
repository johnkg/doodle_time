import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A simple adult-level question (addition with 6..10) with 4 answers.
class GateQuestion {
  GateQuestion._(this.a, this.b, this.options);

  factory GateQuestion.random([math.Random? random]) {
    final r = random ?? math.Random();
    final a = 6 + r.nextInt(5);
    final b = 6 + r.nextInt(5);
    final answer = a + b;
    final set = <int>{answer};
    while (set.length < 4) {
      final wrong = answer + r.nextInt(9) - 4; // answer-4 .. answer+4
      if (wrong > 0) set.add(wrong);
    }
    final options = set.toList()..shuffle(r);
    return GateQuestion._(a, b, options);
  }

  final int a;
  final int b;
  final List<int> options;

  int get answer => a + b;
  bool isCorrect(int value) => value == answer;
}

/// Shows the gate. Resolves true only if the correct answer is tapped.
Future<bool> showParentalGate(BuildContext context) async {
  final q = GateQuestion.random();
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Grown-ups only 🔒'),
      content: Text(
        'What is ${q.a} + ${q.b} ?',
        style: const TextStyle(fontSize: 28),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        for (final o in q.options)
          FilledButton.tonal(
            style: FilledButton.styleFrom(minimumSize: const Size(64, 52)),
            onPressed: () => Navigator.pop(ctx, q.isCorrect(o)),
            child: Text('$o', style: const TextStyle(fontSize: 22)),
          ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
      ],
    ),
  );
  return ok == true;
}
