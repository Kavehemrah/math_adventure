import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:math_adventure/question_engine.dart';

void main() {
  group('QuestionEngine', () {
    test('generates valid four-choice questions for every Grade 4 chapter', () {
      final random = Random(42);
      for (var chapter = 1; chapter <= 7; chapter++) {
        for (var i = 0; i < 100; i++) {
          final question = QuestionEngine.generate(
            chapter: chapter,
            random: random,
          );
          expect(question.chapter, chapter);
          expect(question.prompt, isNotEmpty);
          expect(question.topic, isNotEmpty);
          expect(question.explanation, isNotEmpty);
          expect(question.options, hasLength(4));
          expect(question.options.toSet(), hasLength(4));
          expect(question.options, contains(question.answer));
        }
      }
    });

    test('mixed generation stays within the seven chapters', () {
      final random = Random(7);
      for (var i = 0; i < 500; i++) {
        final question = QuestionEngine.generate(random: random);
        expect(question.chapter, inInclusiveRange(1, 7));
        expect(question.options, contains(question.answer));
      }
    });

    test('rejects an invalid chapter number', () {
      expect(
        () => QuestionEngine.generate(chapter: 8),
        throwsArgumentError,
      );
    });
  });
}
