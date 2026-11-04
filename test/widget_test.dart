import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:math_adventure/main.dart';
import 'package:math_adventure/question_engine.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('home opens a real chapter-specific practice session', (tester) async {
    await tester.pumpWidget(const MathAdventureApp());
    await tester.pumpAndSettle();

    expect(find.text('جادوگران ریاضی'), findsOneWidget);
    await tester.tap(find.text('تمرین فصل‌های ریاضی چهارم'));
    await tester.pumpAndSettle();

    expect(find.text('فصل ۱: اعداد و الگوها'), findsOneWidget);
    await tester.tap(find.text('فصل ۱: اعداد و الگوها'));
    await tester.pump();

    expect(find.text('تمرین فصل ۱'), findsOneWidget);
    expect(find.text('جواب درست را انتخاب کن'), findsOneWidget);
  });

  testWidgets('chapter two opens topic practice and accepts a number-line tap', (tester) async {
    await tester.pumpWidget(const MathAdventureApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('تمرین فصل‌های ریاضی چهارم'));
    await tester.pumpAndSettle();

    final chapterTwo = find.text('فصل ۲: کسر');
    await tester.ensureVisible(chapterTwo);
    await tester.tap(chapterTwo);
    await tester.pumpAndSettle();

    expect(find.text('تمرین فصل دوم: کسر'), findsOneWidget);
    expect(find.text('کسر روی محور اعداد'), findsOneWidget);

    final numberLineTopic = find.text('کسر روی محور اعداد');
    await tester.ensureVisible(numberLineTopic);
    await tester.tap(numberLineTopic);
    await tester.pumpAndSettle();

    // The topic appears both in the game header and in the question card.
    expect(find.text('کسر روی محور اعداد'), findsNWidgets(2));
    final numberLine = find.byWidgetPredicate(
      (widget) =>
          widget is CustomPaint &&
          widget.painter is FractionNumberLinePainter,
    );
    expect(numberLine, findsOneWidget);

    await tester.ensureVisible(numberLine);
    final rect = tester.getRect(numberLine);
    await tester.tapAt(Offset(rect.left + rect.width / 2, rect.center.dy));
    await tester.pumpAndSettle();

    expect(find.text('سؤال بعدی'), findsOneWidget);

    final backToTopics = find.byKey(
      const ValueKey('practice-back-button'),
    );
    await tester.ensureVisible(backToTopics);
    await tester.pumpAndSettle();
    await tester.tap(backToTopics);
    await tester.pumpAndSettle();
    expect(find.text('تمرین فصل دوم: کسر'), findsOneWidget);
  });

  testWidgets('original adventure mode still starts independently', (tester) async {
    await tester.pumpWidget(const MathAdventureApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('شروع بازی'));
    await tester.pump();

    expect(find.text('ماجراجویی ریاضی'), findsOneWidget);
    expect(find.textContaining('از ۳۰'), findsOneWidget);
  });

  test('specific feedback is shown only for a chosen wrong option', () {
    final question = QuestionEngine.generate(
      chapter: 2,
      topic: 'addition',
      random: Random(3),
    );
    final wrong = question.optionFeedback.keys.first;
    expect(
      answerFeedbackText(
        question: question,
        selectedAnswer: wrong,
        timedOut: false,
      ),
      question.optionFeedback[wrong],
    );
    expect(
      answerFeedbackText(
        question: question,
        selectedAnswer: question.answer,
        timedOut: false,
      ),
      question.explanation,
    );
    expect(
      answerFeedbackText(
        question: question,
        selectedAnswer: null,
        timedOut: true,
      ),
      question.explanation,
    );
    expect(
      answerFeedbackText(
        question: question,
        selectedAnswer: 'گزینه‌ای بدون بازخورد',
        timedOut: false,
      ),
      question.explanation,
    );
  });

  testWidgets('a wrong fraction-operation choice shows its own feedback', (tester) async {
    const seed = 11;
    final preview = QuestionEngine.generate(
      chapter: 2,
      topic: 'addition',
      random: Random(seed),
    );
    final wrong = preview.optionFeedback.keys.first;
    final feedback = preview.optionFeedback[wrong]!;

    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: GameScreen(random: Random(seed)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('تمرین فصل‌های ریاضی چهارم'));
    await tester.pumpAndSettle();

    final chapterTwo = find.text('فصل ۲: کسر');
    await tester.ensureVisible(chapterTwo);
    await tester.tap(chapterTwo);
    await tester.pumpAndSettle();

    final addition = find.text('جمع کسرها');
    await tester.ensureVisible(addition);
    await tester.tap(addition);
    await tester.pumpAndSettle();

    expect(find.text(preview.prompt), findsOneWidget);
    final wrongButton = find.widgetWithText(ElevatedButton, wrong);
    await tester.ensureVisible(wrongButton);
    await tester.tap(wrongButton);
    await tester.pumpAndSettle();

    expect(find.text(feedback), findsOneWidget);
    expect(find.text(preview.explanation), findsNothing);
    expect(find.textContaining('جواب درست'), findsWidgets);
  });

  testWidgets('wrong fraction answer offers a distinct score-free remedial question', (tester) async {
    const seed = 11;
    final preview = QuestionEngine.generate(
      chapter: 2,
      topic: 'addition',
      random: Random(seed),
    );
    final wrong = preview.optionFeedback.keys.first;

    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: GameScreen(random: Random(seed)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('تمرین فصل‌های ریاضی چهارم'));
    await tester.pumpAndSettle();
    final chapterTwo = find.text('فصل ۲: کسر');
    await tester.ensureVisible(chapterTwo);
    await tester.tap(chapterTwo);
    await tester.pumpAndSettle();
    final additionTopic = find.text('جمع کسرها');
    await tester.ensureVisible(additionTopic);
    await tester.tap(additionTopic);
    await tester.pumpAndSettle();

    await tester.tap(find.text(wrong));
    await tester.pumpAndSettle();
    final remedialButton = find.byKey(
      const ValueKey('remedial-practice-button'),
    );
    await tester.ensureVisible(remedialButton);
    await tester.tap(remedialButton);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('remedial-practice-banner')), findsOneWidget);
    expect(find.text(preview.prompt), findsNothing);
    expect(find.text('تمرین بیشتر از همین مبحث'), findsNothing);

    // Moving on must leave remedial mode; subsequent questions are normal practice.
    await tester.tap(find.text('سؤال بعدی'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('remedial-practice-banner')), findsNothing);
  });

}
