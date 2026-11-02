import 'dart:ui' show Offset;

import 'package:flutter/widgets.dart' show CustomPaint;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:math_adventure/main.dart';

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

    expect(find.text('کسر روی محور اعداد'), findsOneWidget);
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

    final backToTopics = find.byTooltip('بازگشت به مباحث فصل کسر');
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
}
