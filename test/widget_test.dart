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
}
