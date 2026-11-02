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

    test('each selected chapter two topic generates only its own topic', () {
      const topics = {
        'recognition': 'شناخت کسر',
        'numerator_denominator': 'صورت و مخرج',
        'number_line': 'کسر روی محور اعداد',
        'equivalent': 'کسرهای مساوی',
        'comparison': 'مقایسهٔ کسرها',
        'addition': 'جمع کسرها',
        'subtraction': 'تفریق کسرها',
        'multiplication': 'ضرب عدد در کسر',
      };

      for (final entry in topics.entries) {
        for (var seed = 0; seed < 30; seed++) {
          final question = QuestionEngine.generate(
            chapter: 2,
            topic: entry.key,
            level: seed + 1,
            random: Random(seed),
          );
          expect(question.chapter, 2);
          expect(question.topic, entry.value);
          expect(question.options, hasLength(4));
          expect(question.options.toSet(), hasLength(4));
          expect(question.options, contains(question.answer));
          expect(question.explanation, isNotEmpty);
        }
      }
    });


    test('chapter two questions carry a misconception category for targeted feedback', () {
      const expected = {
        'recognition': 'fraction_parts_confusion',
        'numerator_denominator': 'numerator_denominator_reversed',
        'number_line': 'number_line_equal_intervals',
        'equivalent': 'equivalence_one_sided_change',
        'comparison': 'compare_numerators_only',
        'addition': 'add_denominators',
        'subtraction': 'subtract_denominators',
        'multiplication': 'multiply_denominator',
      };
      for (final entry in expected.entries) {
        final question = QuestionEngine.generate(
          chapter: 2,
          topic: entry.key,
          random: Random(17),
        );
        expect(question.misconceptionCode, entry.value);
      }
    });

    test('chapter two includes contextual problems with valid answer choices', () {
      final found = <String>{};
      for (var seed = 0; seed < 100; seed++) {
        for (final topic in ['addition', 'subtraction', 'multiplication']) {
          final question = QuestionEngine.generate(
            chapter: 2,
            topic: topic,
            random: Random(seed),
          );
          expect(question.options, hasLength(4));
          expect(question.options.toSet(), hasLength(4));
          expect(question.options, contains(question.answer));
          if (question.prompt.contains('کیک')) found.add('addition');
          if (question.prompt.contains('بریده‌ایم')) found.add('subtraction');
          if (question.prompt.contains('بسته')) found.add('multiplication');
        }
      }
      expect(found, containsAll(['addition', 'subtraction', 'multiplication']));
    });

    test('number line questions expose valid touch targets and matching fractions', () {
      for (var seed = 0; seed < 80; seed++) {
        final question = QuestionEngine.generate(
          chapter: 2,
          topic: 'number_line',
          random: Random(seed),
        );
        final line = question.fractionNumberLine!;
        expect(line.divisions, line.tickValues.length - 1);
        expect(line.numerator, inInclusiveRange(1, line.divisions - 1));
        expect(question.answer, line.tickValues[line.numerator]);
        expect(line.tickValues.first, '۰');
        expect(line.tickValues.last, '۱');
      }
    });

    test('fraction recognition rotates between bar, grid and circle visuals', () {
      final styles = <FractionVisualStyle>{};
      for (var seed = 0; seed < 120; seed++) {
        final question = QuestionEngine.generate(
          chapter: 2,
          topic: 'recognition',
          random: Random(seed),
        );
        styles.add(question.fractionVisual!.style);
      }
      expect(styles, containsAll(FractionVisualStyle.values));
    });

    test('rejects an unknown chapter two topic', () {
      expect(
        () => QuestionEngine.generate(chapter: 2, topic: 'unknown'),
        throwsArgumentError,
      );
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
