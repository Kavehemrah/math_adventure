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

    test('chapter three generates valid multiplication questions at low and high levels', () {
      for (final level in [1, 10, 20, 30]) {
        final question = QuestionEngine.generate(
          chapter: 3,
          level: level,
          random: Random(level),
        );
        expect(question.chapter, 3);
        expect(question.options, hasLength(4));
        expect(question.options, contains(question.answer));
      }
    });

    test('chapter two begins with a fraction model and readable Persian values', () {
      for (var level = 1; level <= 3; level++) {
        final question = QuestionEngine.generate(
          chapter: 2,
          level: level,
          random: Random(level),
        );
        expect(question.topic, 'شناخت کسر');
        expect(question.fractionVisual, isNotNull);
        expect(question.prompt, isNot(contains(r'${')));
        expect(question.prompt, contains('قسمت مساوی'));
      }
    });

    test('chapter two progresses from fraction recognition to equivalence and operations', () {
      final recognition = QuestionEngine.generate(chapter: 2, level: 1, random: Random(1));
      final equivalence = QuestionEngine.generate(chapter: 2, level: 4, random: Random(1));
      final addition = QuestionEngine.generate(chapter: 2, level: 7, random: Random(1));
      expect(recognition.topic, 'شناخت کسر');
      expect(equivalence.topic, 'کسرهای مساوی');
      expect(addition.topic, 'جمع کسرها');
    });

    test('rejects chapter numbers outside the supported range', () {
      for (final chapter in [0, 8, -1]) {
        expect(
          () => QuestionEngine.generate(chapter: chapter),
          throwsArgumentError,
        );
      }
    });
  });
}
