import 'dart:math';

class MathQuestion {
  const MathQuestion({
    required this.prompt,
    required this.answer,
    required this.options,
    required this.chapter,
    required this.topic,
    required this.explanation,
  });

  final String prompt;
  final String answer;
  final List<String> options;
  final int chapter;
  final String topic;
  final String explanation;
}

class QuestionEngine {
  QuestionEngine._();

  static MathQuestion generate({int? chapter, int level = 1, Random? random}) {
    final r = random ?? Random();
    final c = chapter ?? r.nextInt(7) + 1;
    if (c < 1 || c > 7) throw ArgumentError.value(c, 'chapter');
    switch (c) {
      case 1: return _chapter1(r);
      case 2: return _chapter2(r);
      case 3: return _chapter3(r, level);
      case 4: return _chapter4(r);
      case 5: return _chapter5(r);
      case 6: return _chapter6(r);
      case 7: return _chapter7(r);
      default: throw StateError('Unknown chapter');
    }
  }

  static MathQuestion _chapter1(Random r) {
    switch (r.nextInt(4)) {
      case 0:
        final n = r.nextInt(90000) + 10000;
        final p = [1, 10, 100, 1000, 10000][r.nextInt(5)];
        final labels = {1: 'یکان', 10: 'دهگان', 100: 'صدگان', 1000: 'هزارگان', 10000: 'ده‌هزارگان'};
        final answer = (n ~/ p) % 10;
        final wrong = List<int>.generate(10, (i) => i)..remove(answer)..shuffle(r);
        return _n(r, 1, 'ارزش مکانی', 'در عدد ${_fa(n)} رقم ${labels[p]} کدام است؟', answer, wrong.take(3).toList(), 'از سمت راست، جایگاه رقم‌ها را می‌شماریم.');
      case 1:
        final first = r.nextInt(15) + 2;
        final step = r.nextInt(8) + 2;
        final answer = first + step * 4;
        return _n(r, 1, 'الگوهای عددی', 'الگو را ادامه بده:\n${_fa(first)}، ${_fa(first + step)}، ${_fa(first + 2 * step)}، ${_fa(first + 3 * step)}، ؟', answer, [answer + step, answer - step, answer + 2], 'در هر مرحله ${_fa(step)} واحد اضافه می‌شود.');
      case 2:
        final input = r.nextInt(15) + 3;
        final factor = r.nextInt(3) + 2;
        final added = r.nextInt(8) + 1;
        final answer = input * factor + added;
        return _n(r, 1, 'ماشین ورودی و خروجی', 'ماشین عدد ورودی را در ${_fa(factor)} ضرب و سپس ${_fa(added)} واحد اضافه می‌کند. خروجی ${_fa(input)} چیست؟', answer, [answer + factor, answer - added, input * factor], 'ابتدا ضرب و سپس جمع را انجام می‌دهیم.');
      default:
        final m = r.nextInt(8) + 1;
        final k = (r.nextInt(9) + 1) * 100;
        final answer = '${_fa(m)} میلیون و ${_fa(k)} هزار';
        return _q(r, 1, 'معرفی میلیون', 'عدد ${_fa(m * 1000000 + k * 1000)} از چند میلیون و چند هزار تشکیل شده است؟', answer, ['${_fa(m + 1)} میلیون و ${_fa(k)} هزار', '${_fa(m)} میلیون و ${_fa(k + 100)} هزار', '${_fa(m - 1)} میلیون و ${_fa(k)} هزار'], 'عدد را به بخش میلیون و بخش هزار تقسیم می‌کنیم.');
    }
  }

  static MathQuestion _chapter2(Random r) {
    final d = [4, 5, 6, 8, 10][r.nextInt(5)];
    switch (r.nextInt(4)) {
      case 0:
        final a = r.nextInt(d - 1) + 1;
        final b = r.nextInt(d - a) + 1;
        return _q(r, 2, 'جمع کسرها', 'حاصل جمع کسرها چیست؟\n${_f(a, d)} + ${_f(b, d)}', _f(a + b, d), [_f(a + b + 1, d), _f(a + b, d + 1), _f(a, d)], 'با برابر بودن مخرج‌ها، صورت‌ها را جمع می‌کنیم.');
      case 1:
        final a = r.nextInt(d - 1) + 2;
        final b = r.nextInt(a - 1) + 1;
        return _q(r, 2, 'تفریق کسرها', 'حاصل تفریق کسرها چیست؟\n${_f(a, d)} − ${_f(b, d)}', _f(a - b, d), [_f(a + b, d), _f(a - b + 1, d), _f(a - b, d + 1)], 'صورت کوچک‌تر را از صورت بزرگ‌تر کم می‌کنیم.');
      case 2:
        final a = r.nextInt(4) + 1;
        final b = a + r.nextInt(5) + 1;
        final factor = r.nextInt(3) + 2;
        return _q(r, 2, 'کسرهای مساوی', 'کدام کسر با ${_f(a, b)} مساوی است؟', _f(a * factor, b * factor), [_f(a + 1, b + factor), _f(a * factor, b), _f(a, b * factor)], 'صورت و مخرج را در یک عدد یکسان ضرب می‌کنیم.');
      default:
        final den = [3, 4, 5, 6][r.nextInt(4)];
        final num = r.nextInt(den - 1) + 1;
        final whole = r.nextInt(5) + 2;
        return _q(r, 2, 'ضرب عدد در کسر', '${_fa(whole)} × ${_f(num, den)} = ؟', _f(whole * num, den), [_f(whole + num, den), _f(whole * num + 1, den), _f(whole * num, den + 1)], 'عدد صحیح را در صورت ضرب می‌کنیم و مخرج ثابت می‌ماند.');
    }
  }

  static MathQuestion _chapter3(Random r, int level) {
    switch (r.nextInt(4)) {
      case 0:
        final maxFactor = level <= 10 ? 39 : level <= 20 ? 69 : 99;
        final a = r.nextInt(maxFactor - 10) + 11;
        final b = r.nextInt(maxFactor - 10) + 11;
        final answer = a * b;
        return _n(r, 3, 'ضرب دورقمی', '${_fa(a)} × ${_fa(b)} = ؟', answer, [answer + b, answer - b, answer + 1], 'دو عدد دورقمی را در هم ضرب می‌کنیم.');
      case 1:
        final a = (r.nextInt(8) + 2) * 10 + r.nextInt(9);
        final b = (r.nextInt(7) + 2) * 10 + r.nextInt(9);
        final ra = ((a + 5) ~/ 10) * 10;
        final rb = ((b + 5) ~/ 10) * 10;
        final answer = ra * rb;
        return _n(r, 3, 'تقریب حاصل‌ضرب', 'برای تخمین ${_fa(a)} × ${_fa(b)}، هر عدد را به نزدیک‌ترین دهگان گرد کن.', answer, [a * b, answer + 100, (answer - 100).abs()], 'ابتدا هر دو عدد را به نزدیک‌ترین دهگان گرد می‌کنیم.');
      case 2:
        final divisor = r.nextInt(8) + 2;
        final quotient = r.nextInt(30) + 5;
        final dividend = divisor * quotient;
        return _n(r, 3, 'تقسیم', '${_fa(dividend)} ÷ ${_fa(divisor)} = ؟', quotient, [quotient + 1, quotient - 1, quotient + divisor], 'چون ${_fa(quotient)} × ${_fa(divisor)} برابر ${_fa(dividend)} است، خارج‌قسمت همین عدد است.');
      default:
        final divisor = [2, 3, 5, 10][r.nextInt(4)];
        final number = r.nextInt(900) + 100;
        final divisible = number % divisor == 0;
        return _q(r, 3, 'بخش‌پذیری', 'آیا عدد ${_fa(number)} بر ${_fa(divisor)} بخش‌پذیر است؟', divisible ? 'بله' : 'خیر', [divisible ? 'خیر' : 'بله', 'همیشه', 'اطلاعات کافی نیست'], divisible ? 'تقسیم بدون باقیمانده انجام می‌شود.' : 'تقسیم دارای باقیمانده است.');
    }
  }

  static MathQuestion _chapter4(Random r) {
    switch (r.nextInt(4)) {
      case 0:
        final angle = [35, 60, 90, 115, 140, 170][r.nextInt(6)];
        final answer = angle < 90 ? 'تند' : angle == 90 ? 'قائمه' : 'باز';
        final wrong = ['تند', 'قائمه', 'باز', 'مستقیم']..remove(answer);
        return _q(r, 4, 'زاویه', 'زاویه ${_fa(angle)} درجه چه نوع زاویه‌ای است؟', answer, wrong, 'کمتر از ۹۰ درجه تند، ۹۰ درجه قائمه و بیشتر از ۹۰ درجه باز است.');
      case 1:
        final meters = r.nextInt(8) + 1;
        final centimeters = r.nextInt(10) * 10;
        final answer = meters * 100 + centimeters;
        return _n(r, 4, 'تبدیل واحد طول', '${_fa(meters)} متر و ${_fa(centimeters)} سانتی‌متر چند سانتی‌متر است؟', answer, [answer + 10, answer - 10, meters + centimeters], 'هر متر ۱۰۰ سانتی‌متر است.', ' سانتی‌متر');
      case 2:
        final hours = r.nextInt(4) + 1;
        final minutes = hours * 60;
        return _n(r, 4, 'تبدیل واحد زمان', '${_fa(hours)} ساعت چند دقیقه است؟', minutes, [minutes + 30, minutes - 30, hours * 60 + 10], 'هر ساعت ۶۰ دقیقه است؛ تعداد ساعت‌ها را در ۶۰ ضرب می‌کنیم.', ' دقیقه');
      default:
        final start = r.nextInt(4) + 8;
        final duration = [20, 30, 40, 45, 50, 60][r.nextInt(6)];
        final total = start * 60 + duration;
        final hour = total ~/ 60;
        final minute = total % 60;
        final answer = '${_fa(hour)}:${_fa(minute.toString().padLeft(2, '0'))}';
        return _q(r, 4, 'زمان', 'کلاسی ساعت ${_fa(start)}:۰۰ شروع می‌شود و ${_fa(duration)} دقیقه طول می‌کشد. چه ساعتی تمام می‌شود؟', answer, ['${_fa(hour)}:${_fa((minute + 10) % 60)}', '${_fa(hour + 1)}:${_fa(minute)}', '${_fa(hour - 1)}:${_fa(minute)}'], 'مدت زمان را به ساعت شروع اضافه می‌کنیم.');
    }
  }

  static MathQuestion _chapter5(Random r) {
    switch (r.nextInt(3)) {
      case 0:
        final a = r.nextInt(80) + 10;
        final b = r.nextInt(80) + 10;
        final subtract = r.nextBool();
        final left = subtract ? (a > b ? a : b) : a;
        final right = subtract ? (a < b ? a : b) : b;
        final result = subtract ? left - right : left + right;
        return _q(r, 5, subtract ? 'تفریق اعشاری' : 'جمع اعشاری', '${_decimal(left)} ${subtract ? '−' : '+'} ${_decimal(right)} = ؟', _decimal(result), [_decimal(result + 1), _decimal(result > 0 ? result - 1 : result + 2), _decimal(result + 10)], 'ارزش مکانی رقم‌های اعشاری را یکسان می‌کنیم.');
      case 1:
        final whole = r.nextInt(5) + 1;
        final numerator = r.nextInt(3) + 1;
        final decimalPart = numerator * 25;
        return _q(r, 5, 'عدد مخلوط', 'عدد مخلوط ${_fa(whole)} و ${_f(numerator, 4)} به صورت اعشاری کدام است؟', _decimal2(whole * 100 + decimalPart), [_decimal2(whole * 100 + numerator * 10), _decimal2(whole * 100 + 4 * 10), _decimal2(whole * 100 - decimalPart)], 'کسر را به اعشار تبدیل می‌کنیم و به بخش صحیح می‌افزاییم.');
      default:
        final whole = r.nextInt(8) + 1;
        final tenths = r.nextInt(10);
        final hundredths = r.nextInt(10);
        final value = whole * 100 + tenths * 10 + hundredths;
        return _n(r, 5, 'ارزش مکانی اعشار', 'در عدد ${_decimal2(value)}، رقم دهم کدام است؟', tenths, [whole, hundredths, (tenths + 1) % 10], 'اولین رقم پس از ممیز، رقم دهم است.');
    }
  }

  static MathQuestion _chapter6(Random r) {
    switch (r.nextInt(5)) {
      case 0:
        final a = r.nextInt(12) + 4;
        final b = r.nextInt(8) + 3;
        return _n(r, 6, 'محیط مستطیل', 'طول مستطیل ${_fa(a)} و عرض آن ${_fa(b)} سانتی‌متر است. محیط چقدر است؟', 2 * (a + b), [a * b, 2 * (a + b) + a, 2 * (a + b) - b], 'محیط مستطیل از جمع چهار ضلع، یعنی دو برابر مجموع طول و عرض، به دست می‌آید.', ' سانتی‌متر');
      case 1:
        final a = r.nextInt(12) + 4;
        final b = r.nextInt(8) + 3;
        return _n(r, 6, 'مساحت مستطیل', 'طول مستطیل ${_fa(a)} و عرض آن ${_fa(b)} سانتی‌متر است. مساحت چقدر است؟', a * b, [2 * (a + b), a * b + a, a * b - b], 'مساحت مستطیل برابر طول ضربدر عرض است.', ' سانتی‌متر مربع');
      case 2:
        final base = r.nextInt(12) + 4;
        final height = r.nextInt(8) + 3;
        return _n(r, 6, 'مساحت متوازی‌الاضلاع', 'قاعده ${_fa(base)} و ارتفاع ${_fa(height)} سانتی‌متر است. مساحت چقدر است؟', base * height, [2 * (base + height), base * height + base, base * height - height], 'مساحت متوازی‌الاضلاع برابر قاعده ضربدر ارتفاع است.', ' سانتی‌متر مربع');
      case 3:
        final base = (r.nextInt(8) + 2) * 2;
        final height = r.nextInt(8) + 2;
        final area = base * height ~/ 2;
        return _n(r, 6, 'مساحت مثلث', 'قاعده مثلث ${_fa(base)} و ارتفاع آن ${_fa(height)} سانتی‌متر است. مساحت چقدر است؟', area, [base * height, area + base, area + height], 'مساحت مثلث نصف حاصل‌ضرب قاعده در ارتفاع است.', ' سانتی‌متر مربع');
      case 4:
        final parallel = r.nextBool();
        return _q(r, 6, 'ویژگی چهارضلعی‌ها و خط‌ها', parallel ? 'کدام دو شکل چهار زاویه قائمه دارند؟' : 'دو خط که با زاویه ۹۰ درجه یکدیگر را قطع می‌کنند چه نام دارند؟', parallel ? 'مربع و مستطیل' : 'عمود', parallel ? ['لوزی و ذوزنقه', 'مثلث و مربع', 'دایره و مستطیل'] : ['موازی', 'منحنی', 'هم‌جهت'], parallel ? 'مربع و مستطیل هر دو چهار زاویه قائمه دارند.' : 'خطوط عمود زاویه قائمه می‌سازند.');
    }
  }

  static MathQuestion _chapter7(Random r) {
    switch (r.nextInt(4)) {
      case 0:
        final values = List<int>.generate(4, (_) => r.nextInt(8) + 2);
        final total = values.reduce((a, b) => a + b);
        final days = ['شنبه', 'یکشنبه', 'دوشنبه', 'سه‌شنبه'];
        final rows = List.generate(4, (i) => '${days[i]} ${_fa(values[i])}').join('، ');
        return _n(r, 7, 'خواندن نمودار', 'تعداد کتاب‌های خوانده‌شده:\n${rows}\nدر مجموع چند کتاب خوانده شده است؟', total, [total + 2, total > 2 ? total - 2 : total + 3, values.reduce((a, b) => a > b ? a : b)], 'مقدار چهار روز را با هم جمع می‌کنیم.', ' کتاب');
      case 1:
        final days = ['شنبه', 'یکشنبه', 'دوشنبه', 'سه‌شنبه'];
        final firstValue = r.nextInt(10) + 1;
        final values = [firstValue, firstValue + 1, firstValue + 2, firstValue + 3]..shuffle(r);
        final maxValue = values.reduce((a, b) => a > b ? a : b);
        final answer = days[values.indexOf(maxValue)];
        final wrong = days.where((day) => day != answer).toList()..shuffle(r);
        final rows = List.generate(4, (i) => '${days[i]}: ${_fa(values[i])}').join('، ');
        return _q(r, 7, 'بیشترین مقدار در نمودار', 'مقدارهای ثبت‌شده:\n${rows}\nبیشترین مقدار مربوط به کدام روز است؟', answer, wrong, 'بزرگ‌ترین عدد جدول را پیدا می‌کنیم.');
      case 2:
        final total = r.nextInt(5) + 5;
        final red = r.nextInt(total - 1) + 1;
        final blue = total - red;
        return _q(r, 7, 'احتمال ساده', 'در کیسه‌ای ${_fa(red)} مهره قرمز و ${_fa(blue)} مهره آبی است. احتمال بیرون آوردن مهره قرمز کدام است؟', _f(red, total), [_f(blue, total), _f(red + 1, total), _f(1, total)], 'احتمال برابر تعداد حالت مطلوب تقسیم بر تعداد کل حالت‌هاست.');
      default:
        final impossible = r.nextBool();
        return _q(r, 7, 'مقایسه احتمال', impossible ? 'در پرتاب یک تاس معمولی، عدد ۷ بیاید.' : 'فردا صبح خورشید طلوع کند.', impossible ? 'غیرممکن' : 'قطعی', impossible ? ['قطعی', 'کم', 'زیاد'] : ['غیرممکن', 'کم', 'برابر'], 'به حالت‌های ممکن این رویداد توجه می‌کنیم.');
    }
  }

  static MathQuestion _n(Random r, int chapter, String topic, String prompt,
      int answer, List<int> wrong, String explanation, [String suffix = '']) {
    return _q(r, chapter, topic, prompt, '${_fa(answer)}$suffix',
        wrong.map((x) => '${_fa(x)}$suffix').toList(), explanation);
  }

  static MathQuestion _q(Random r, int chapter, String topic, String prompt,
      String answer, List<String> wrong, String explanation) {
    final set = <String>{answer};
    for (final item in wrong) {
      if (item != answer && set.length < 4) set.add(item);
    }
    var fallback = 1;
    while (set.length < 4) {
      set.add('گزینه ${_fa(fallback)}');
      fallback++;
    }
    final options = set.toList()..shuffle(r);
    return MathQuestion(
      prompt: prompt,
      answer: answer,
      options: List.unmodifiable(options),
      chapter: chapter,
      topic: topic,
      explanation: explanation,
    );
  }

  static String _f(int n, int d) {
    final gcd = n.gcd(d);
    final numerator = n ~/ gcd;
    final denominator = d ~/ gcd;
    return denominator == 1 ? _fa(numerator) : '${_fa(numerator)}/${_fa(denominator)}';
  }

  static String _decimal(int value) {
    final whole = value ~/ 10;
    final tenth = value % 10;
    return '${_fa(whole)}٫${_fa(tenth)}';
  }
  static String _decimal2(int value) {
    final whole = value ~/ 100;
    final rest = (value % 100).toString().padLeft(2, '0');
    return '${_fa(whole)}٫${_fa(rest)}';
  }

  static String _fa(Object value) {
    const en = '0123456789';
    const fa = '۰۱۲۳۴۵۶۷۸۹';
    var text = value.toString();
    for (var i = 0; i < en.length; i++) {
      text = text.replaceAll(en[i], fa[i]);
    }
    return text;
  }
}
