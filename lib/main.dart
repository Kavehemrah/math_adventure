
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'question_engine.dart';

void main() {
  runApp(const MathAdventureApp());
}

String fa(String value) {
  const en = '0123456789';
  const faDigits = '۰۱۲۳۴۵۶۷۸۹';
  for (int i = 0; i < en.length; i++) {
    value = value.replaceAll(en[i], faDigits[i]);
  }
  return value;
}

/// توضیح بعد از پاسخ. بازخورد اختصاصی فقط برای گزینهٔ غلطِ پاسخ‌داده‌شده است،
/// نه برای پاسخ درست، نه وقتی وقت تمام شده، و نه اگر آن گزینه بازخوردی نداشته باشد.
@visibleForTesting
String answerFeedbackText({
  required MathQuestion question,
  required String? selectedAnswer,
  required bool timedOut,
}) {
  if (!timedOut &&
      selectedAnswer != null &&
      selectedAnswer != question.answer) {
    final specific = question.optionFeedback[selectedAnswer];
    if (specific != null && specific.isNotEmpty) return specific;
  }
  return question.explanation;
}

class MathAdventureApp extends StatelessWidget {
  const MathAdventureApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'جادوگران ریاضی',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF6846D8),
        scaffoldBackgroundColor: const Color(0xFFF5F2FF),
      ),
      home: const Directionality(
        textDirection: TextDirection.rtl,
        child: GameScreen(),
      ),
    );
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, this.random});

  /// در تست می‌توان منبع تصادفی را ثابت کرد تا همان سؤال دوباره ساخته شود.
  final Random? random;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final Random random = widget.random ?? Random();

  Timer? timer;
  int bestScore = 0;
  int unlockedLevel = 1;
  int totalScore = 0;
  int levelsCleared = 0;
  int score = 0;
  int level = 1;
  int lives = 3;
  int timeLeft = 40;
  int questionInLevel = 0;
  String correctAnswer = '';
  String? selectedAnswer;
  int? selectedChapter;
  String? selectedTopic;
  MathQuestion? currentQuestion;
  final Map<String, int> topicProgress = {};

  String question = '';
  String operationName = '';
  List<String> options = [];

  bool answered = false;
  bool gameStarted = false;
  bool showMap = false;
  bool showChapterMenu = false;
  bool showTopicMenu = false;
  bool gameOver = false;
  bool timedOut = false;
  bool isRemedialPractice = false;

  @override
  void initState() {
    super.initState();
    loadBestScore();
  }

  // Ranks are ordered from lowest to highest.
  static const List<String> rankNames = [
    'noob',
    'good',
    'pro',
    'master',
    'grand master',
    'hacker',
    'god of math',
  ];
  static const List<String> rankEmojis = [
    '🐣', '👍', '⚡', '🥋', '🏆', '💻', '👑',
  ];
  static const List<int> rankThresholds = [0, 100, 350, 800, 1600, 2800, 4500];

  int get rankPoints => totalScore + (unlockedLevel - 1) * 100 + levelsCleared * 50;

  int get rankIndex {
    var index = 0;
    for (var i = 0; i < rankThresholds.length; i++) {
      if (rankPoints >= rankThresholds[i]) index = i;
    }
    return index;
  }

  double get rankProgress {
    if (rankIndex == rankNames.length - 1) return 1;
    final start = rankThresholds[rankIndex];
    final end = rankThresholds[rankIndex + 1];
    return ((rankPoints - start) / (end - start)).clamp(0.0, 1.0).toDouble();
  }

  Future<void> loadBestScore() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTopicProgress = <String, int>{};
    for (final key in prefs.getKeys()) {
      if (key.startsWith('chapter2_topic_')) {
        savedTopicProgress[key.substring('chapter2_topic_'.length)] =
            prefs.getInt(key) ?? 0;
      }
    }
    if (!mounted) return;
    setState(() {
      topicProgress
        ..clear()
        ..addAll(savedTopicProgress);
      bestScore = prefs.getInt('best_score') ?? 0;
      unlockedLevel = (prefs.getInt('unlocked_level') ?? 1).clamp(1, 30).toInt();
      totalScore = prefs.getInt('total_score') ?? 0;
      levelsCleared = prefs.getInt('levels_cleared') ?? 0;
    });
  }

  Future<void> saveBestScore() async {
    if (score > bestScore) bestScore = score;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('best_score', bestScore);
    await prefs.setInt('total_score', totalScore);
    await prefs.setInt('levels_cleared', levelsCleared);
    await prefs.setInt('unlocked_level', unlockedLevel);
  }

  Future<void> saveProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('total_score', totalScore);
    await prefs.setInt('levels_cleared', levelsCleared);
    await prefs.setInt('unlocked_level', unlockedLevel);
    if (selectedTopic != null) {
      await prefs.setInt(
        'chapter2_topic_$selectedTopic',
        topicProgress[selectedTopic!] ?? 0,
      );
    }
  }

  Future<void> saveUnlockedLevel() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('unlocked_level', unlockedLevel);
  }

  void startGame({
    int? startingLevel,
    int? chapter,
    String? topic,
  }) {
    timer?.cancel();
    setState(() {
      score = 0;
      isRemedialPractice = false;
      level = startingLevel ?? 1;
      selectedChapter = chapter;
      selectedTopic = topic;
      showTopicMenu = false;
      currentQuestion = null;
      lives = 3;
      questionInLevel = 0;
      gameStarted = true;
      showMap = false;
      showChapterMenu = false;
      gameOver = false;
      createQuestion();
    });
    if (chapter == null) startTimer();
  }

  int get questionTimeLimit => level <= 3 ? 25 : level <= 6 ? 30 : level <= 10 ? 35 : 40;

  void startTimer() {
    if (selectedChapter != null) return;
    timer?.cancel();
    timeLeft = questionTimeLimit;
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || answered || gameOver || !gameStarted) {
        t.cancel();
        return;
      }
      setState(() {
        timeLeft--;
      });
      if (timeLeft <= 0) {
        t.cancel();
        answerQuestion(null);
      }
    });
  }

  void createQuestion() {
    answered = false;
    timedOut = false;
    selectedAnswer = null;

    if (selectedChapter != null) {
      currentQuestion = QuestionEngine.generate(
        chapter: selectedChapter,
        level: level,
        topic: selectedTopic,
        random: random,
      );
      question = currentQuestion!.prompt;
      correctAnswer = currentQuestion!.answer;
      options = currentQuestion!.options;
      return;
    }
    currentQuestion = null;

    int a;
    int b;
    int result;
    String op;

    final List<String> operations = level <= 3
        ? ['+', '-']
        : level <= 6
            ? ['+', '-', '×']
            : ['+', '-', '×', '÷'];

    op = operations[random.nextInt(operations.length)];

    if (level <= 3) {
      a = random.nextInt(20) + 1;
      b = random.nextInt(20) + 1;
    } else if (level <= 6) {
      a = random.nextInt(50) + 10;
      b = random.nextInt(30) + 1;
    } else if (level <= 10) {
      a = random.nextInt(90) + 10;
      b = random.nextInt(30) + 2;
    } else if (level <= 15) {
      a = random.nextInt(180) + 20;
      b = random.nextInt(40) + 2;
    } else if (level <= 20) {
      a = random.nextInt(250) + 50;
      b = random.nextInt(50) + 2;
    } else if (level <= 25) {
      a = random.nextInt(400) + 100;
      b = random.nextInt(60) + 2;
    } else {
      a = random.nextInt(800) + 100;
      b = random.nextInt(80) + 2;
    }

    if (op == '-' && b > a) {
      final temp = a;
      a = b;
      b = temp;
    }

    if (op == '÷') {
      result = random.nextInt(min(level + 5, 30)) + 2;
      b = random.nextInt(min(5 + level, 40)) + 2;
      a = result * b;
    } else if (op == '×') {
      final maxFactor = level <= 6
          ? 12
          : level <= 10
              ? 15
              : level <= 15
                  ? 20
                  : level <= 20
                      ? 25
                      : level <= 25
                          ? 30
                          : 40;
      a = random.nextInt(maxFactor - 1) + 2;
      b = random.nextInt(maxFactor - 1) + 2;
      result = a * b;
    } else if (op == '+') {
      result = a + b;
    } else {
      result = a - b;
    }

    correctAnswer = result.toString();
    question = '${fa('$a')} $op ${fa('$b')} = ؟';

    final Set<int> choices = {result};
    while (choices.length < 4) {
      final offset = random.nextInt(15) - 7;
      final candidate = result + (offset == 0 ? 9 : offset);
      if (candidate >= 0 && candidate != result) {
        choices.add(candidate);
      }
    }

    options = choices.map((value) => value.toString()).toList()..shuffle(random);
  }

  void answerQuestion(String? value) {
    if (answered || gameOver) return;

    timer?.cancel();
    HapticFeedback.selectionClick();

    setState(() {
      answered = true;
      selectedAnswer = value;
      timedOut = value == null;

      if (isRemedialPractice) {
        // تمرین جبرانی آموزشی است و در امتیاز، جان یا پیشرفت ثبت نمی‌شود.
      } else if (value == correctAnswer) {
        final int earned = 10 + max(0, timeLeft ~/ 5).toInt();
        score += earned;
        totalScore += earned;
        questionInLevel++;
        if (selectedTopic != null) {
          topicProgress[selectedTopic!] =
              (topicProgress[selectedTopic!] ?? 0) + 1;
        }
        if (selectedChapter != null) level++;
        SystemSound.play(SystemSoundType.click);

        if (selectedChapter == null && questionInLevel >= 5) {
          levelsCleared++;
          if (level < 30) level++;
          if (level > unlockedLevel && level <= 30) {
            unlockedLevel = level;
          }
          questionInLevel = 0;
        }
        saveProgress();
      } else {
        lives--;
        HapticFeedback.heavyImpact();
      }
    });

    if (lives <= 0) {
      finishGame();
    }
  }

  Future<void> finishGame() async {
    timer?.cancel();
    await saveBestScore();
    if (!mounted) return;
    setState(() {
      gameOver = true;
    });
  }

  void startRemedialPractice() {
    if (selectedChapter != 2 || selectedTopic == null || currentQuestion == null) {
      return;
    }
    final previousPrompt = currentQuestion!.prompt;
    MathQuestion replacement;
    var attempts = 0;
    do {
      replacement = QuestionEngine.generate(
        chapter: 2,
        topic: selectedTopic,
        level: level,
        random: random,
      );
      attempts++;
    } while (replacement.prompt == previousPrompt && attempts < 30);

    if (replacement.prompt == previousPrompt) return;
    setState(() {
      isRemedialPractice = true;
      currentQuestion = replacement;
      question = replacement.prompt;
      correctAnswer = replacement.answer;
      options = replacement.options;
      answered = false;
      selectedAnswer = null;
      timedOut = false;
    });
  }

  void nextQuestion() {
    if (gameOver) return;
    setState(() {
      // Leaving a remedial question returns the session to normal practice.
      isRemedialPractice = false;
      createQuestion();
    });
    if (selectedChapter == null) startTimer();
  }

  void goHome() {
    timer?.cancel();
    setState(() {
      gameStarted = false;
      showMap = false;
      showChapterMenu = false;
      showTopicMenu = false;
      selectedChapter = null;
      selectedTopic = null;
      currentQuestion = null;
      gameOver = false;
    });
  }

  void backFromPractice() {
    if (selectedChapter == 2 && selectedTopic != null) {
      timer?.cancel();
      setState(() {
        gameStarted = false;
        showMap = false;
        showChapterMenu = false;
        showTopicMenu = true;
        selectedChapter = null;
        selectedTopic = null;
        currentQuestion = null;
        gameOver = false;
      });
      return;
    }
    goHome();
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: gameOver
                  ? buildGameOver()
                  : showMap
                      ? buildLevelMap()
                      : showChapterMenu
                          ? buildChapterMenu()
                          : showTopicMenu
                              ? buildTopicMenu()
                              : !gameStarted
                          ? buildHome()
                          : buildGame(),
            ),
          ),
        ),
      ),
    );
  }

  Widget buildHome() {
    // Keep the main actions visible on typical phone screens.
    final compact = MediaQuery.sizeOf(context).height < 760;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: compact ? 4 : 12),
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            vertical: compact ? 10 : 16,
            horizontal: 12,
          ),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF2D145F),
                Color(0xFF6846D8),
                Color(0xFFB18CFF),
              ],
              begin: Alignment.bottomLeft,
              end: Alignment.topRight,
            ),
            borderRadius: BorderRadius.circular(26),
          ),
          child: Column(
            children: [
              Text('✨  🌙  ✨', style: TextStyle(fontSize: compact ? 17 : 20)),
              SizedBox(height: compact ? 2 : 5),
              Text('🏰', style: TextStyle(fontSize: compact ? 58 : 70)),
              Text('🐉  🪄  🐲', style: TextStyle(fontSize: compact ? 25 : 29)),
              SizedBox(height: compact ? 2 : 5),
              const Text(
                'سرزمین جادو',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: compact ? 8 : 12),
        Text(
          'جادوگران ریاضی',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: compact ? 27 : 31,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF39246B),
          ),
        ),
        SizedBox(height: compact ? 3 : 7),
        Text(
          'فکر کن، جواب بده و قهرمان شو!',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: compact ? 15 : 17,
            color: Colors.black54,
          ),
        ),
        SizedBox(height: compact ? 12 : 18),
        buildRankCard(),
        SizedBox(height: compact ? 10 : 14),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(compact ? 14 : 18),
          decoration: cardDecoration(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.emoji_events, color: Colors.amber, size: 27),
                  const SizedBox(width: 7),
                  Text(
                    'بهترین امتیاز: ${fa('$bestScore')}',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              SizedBox(height: compact ? 10 : 15),
              SizedBox(
                width: double.infinity,
                height: compact ? 50 : 56,
                child: ElevatedButton.icon(
                  onPressed: startGame,
                  icon: const Icon(Icons.play_arrow_rounded, size: 28),
                  label: const Text(
                    'شروع بازی',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  style: primaryButtonStyle(),
                ),
              ),
              SizedBox(height: compact ? 8 : 11),
              SizedBox(
                width: double.infinity,
                height: compact ? 46 : 50,
                child: OutlinedButton.icon(
                  onPressed: () => setState(() => showChapterMenu = true),
                  icon: const Icon(Icons.menu_book_rounded),
                  label: const Text(
                    'تمرین فصل‌های ریاضی چهارم',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF6846D8),
                    side: const BorderSide(color: Color(0xFF6846D8), width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              SizedBox(height: compact ? 8 : 11),
              SizedBox(
                width: double.infinity,
                height: compact ? 46 : 50,
                child: OutlinedButton.icon(
                  onPressed: () => setState(() => showMap = true),
                  icon: const Icon(Icons.map_rounded),
                  label: const Text(
                    'نقشه سرزمین جادو',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF6846D8),
                    side: const BorderSide(
                      color: Color(0xFF6846D8),
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: compact ? 8 : 14),
        Text(
          '➕ جمع   ➖ تفریق   ✖️ ضرب   ➗ تقسیم',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: compact ? 13 : 15),
        ),
        SizedBox(height: compact ? 2 : 8),
      ],
    );
  }

  Widget buildRankCard() {
    final currentRank = rankIndex;
    final isMaxRank = currentRank == rankNames.length - 1;
    final nextThreshold = isMaxRank ? rankPoints : rankThresholds[currentRank + 1];
    final remaining = max(0, nextThreshold - rankPoints);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD9CCFF)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(rankEmojis[currentRank], style: const TextStyle(fontSize: 34)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('رتبهٔ جادویی تو', style: TextStyle(fontSize: 13, color: Colors.black54)),
                    Text(rankNames[currentRank], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF39246B))),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(fa('$rankPoints'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                  const Text('امتیاز رتبه', style: TextStyle(fontSize: 11, color: Colors.black54)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: rankProgress,
              minHeight: 8,
              backgroundColor: const Color(0xFFEDE7F6),
              color: const Color(0xFF6846D8),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            isMaxRank
                ? 'به بالاترین رتبه رسیدی! 👑'
                : 'تا رتبهٔ بعدی: ${fa('$remaining')} امتیاز رتبه',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 4),
          Text(
            'امتیاز کل: ${fa('$totalScore')}  •  مرحله‌های تکمیل‌شده: ${fa('$levelsCleared')}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  static const List<Map<String, String>> grade4Chapters = [
    {'title': 'اعداد و الگوها', 'icon': '🔢', 'topics': 'عددنویسی، الگوها، ماشین ورودی‌ـ‌خروجی، میلیون'},
    {'title': 'کسر', 'icon': '🍕', 'topics': 'شناخت کسر، جمع و تفریق، تساوی کسرها، ضرب عدد در کسر'},
    {'title': 'ضرب و تقسیم', 'icon': '✖️', 'topics': 'ضرب دورقمی، تقریب، تقسیم و بخش‌پذیری'},
    {'title': 'اندازه‌گیری', 'icon': '📐', 'topics': 'زاویه، زمان و طول'},
    {'title': 'عدد مخلوط و عدد اعشاری', 'icon': '🔟', 'topics': 'عدد مخلوط، اعشار، جمع و تفریق، ارزش مکانی'},
    {'title': 'شکل‌های هندسی', 'icon': '🔷', 'topics': 'عمود و موازی، چهارضلعی، مساحت و محیط'},
    {'title': 'آمار و احتمال', 'icon': '📊', 'topics': 'نمودار خط شکسته و احتمال'},
  ];

  static const List<Map<String, String>> grade4Chapter2Topics = [
    {
      'id': 'recognition',
      'title': 'شناخت کسر',
      'subtitle': 'کسر یعنی چند قسمت از یک واحد',
      'icon': '🍕',
    },
    {
      'id': 'numerator_denominator',
      'title': 'صورت و مخرج',
      'subtitle': 'بالا و پایین خط کسر را بشناس',
      'icon': '🔢',
    },
    {
      'id': 'number_line',
      'title': 'کسر روی محور اعداد',
      'subtitle': 'نقطهٔ درست را روی محور لمس کن',
      'icon': '📍',
    },
    {
      'id': 'equivalent',
      'title': 'کسرهای مساوی',
      'subtitle': 'کسرهایی با اندازهٔ یکسان',
      'icon': '🟰',
    },
    {
      'id': 'comparison',
      'title': 'مقایسهٔ کسرها',
      'subtitle': 'بزرگ‌تر، کوچک‌تر یا مساوی',
      'icon': '⚖️',
    },
    {
      'id': 'addition',
      'title': 'جمع کسرها',
      'subtitle': 'جمع کسرها با مخرج برابر',
      'icon': '➕',
    },
    {
      'id': 'subtraction',
      'title': 'تفریق کسرها',
      'subtitle': 'تفریق کسرها با مخرج برابر',
      'icon': '➖',
    },
    {
      'id': 'multiplication',
      'title': 'ضرب عدد در کسر',
      'subtitle': 'ضرب عدد صحیح در یک کسر',
      'icon': '✖️',
    },
  ];

  String topicTitle(String? topic) {
    for (final item in grade4Chapter2Topics) {
      if (item['id'] == topic) return item['title']!;
    }
    return 'تمرین کسر';
  }

  Widget buildTopicMenu() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('🍕', textAlign: TextAlign.center, style: TextStyle(fontSize: 54)),
        const Text(
          'تمرین فصل دوم: کسر',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w900,
            color: Color(0xFF39246B),
          ),
        ),
        const SizedBox(height: 7),
        const Text(
          'امروز روی کدام مبحث کار می‌کنی؟',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Colors.black54),
        ),
        const SizedBox(height: 16),
        ...grade4Chapter2Topics.map((topic) {
          final id = topic['id']!;
          final completed = topicProgress[id] ?? 0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => startGame(chapter: 2, topic: id),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Text(topic['icon']!, style: const TextStyle(fontSize: 28)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              topic['title']!,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF39246B),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              topic['subtitle']!,
                              style: const TextStyle(fontSize: 11, color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        children: [
                          const Icon(
                            Icons.check_circle_outline_rounded,
                            color: Color(0xFF55B879),
                            size: 20,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            fa('$completed'),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF665A83),
                            ),
                          ),
                          const Text(
                            'درست',
                            style: TextStyle(
                              fontSize: 8,
                              color: Color(0xFF8A819D),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => setState(() {
            showTopicMenu = false;
            showChapterMenu = true;
          }),
          icon: const Icon(Icons.arrow_forward_rounded),
          label: const Text('بازگشت به فصل‌ها'),
        ),
      ],
    );
  }

  Widget buildChapterMenu() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('📚', textAlign: TextAlign.center, style: TextStyle(fontSize: 58)),
        const Text('تمرین فصل‌های ریاضی چهارم', textAlign: TextAlign.center,
          style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900, color: Color(0xFF39246B))),
        const SizedBox(height: 8),
        const Text('فصل موردنظر را انتخاب کن', textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, color: Colors.black54)),
        const SizedBox(height: 16),
        ...grade4Chapters.asMap().entries.map((entry) {
          final index = entry.key;
          final chapter = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () {
                  if (index == 1) {
                    setState(() {
                      showChapterMenu = false;
                      showTopicMenu = true;
                    });
                  } else {
                    startGame(chapter: index + 1);
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(children: [
                    Text(chapter['icon']!, style: const TextStyle(fontSize: 30)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('فصل ${fa('${index + 1}')}: ${chapter['title']}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(chapter['topics']!,
                        style: const TextStyle(fontSize: 12, color: Colors.black54)),
                    ])),
                    const Icon(Icons.play_circle_fill_rounded, color: Color(0xFF6846D8)),
                  ]),
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => setState(() => showChapterMenu = false),
          icon: const Icon(Icons.home_rounded),
          label: const Text('بازگشت به خانه'),
        ),
      ],
    );
  }

  Widget buildLevelMap() {
    return Column(
      children: [
        const Text('🗺️', style: TextStyle(fontSize: 62)),
        const SizedBox(height: 8),
        const Text(
          'نقشه سرزمین جادو',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF39246B)),
        ),
        const SizedBox(height: 8),
        Text(
          'مرحله‌های بازشده: ${fa('$unlockedLevel')} از ۳۰',
          style: const TextStyle(fontSize: 16, color: Colors.black54),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: cardDecoration(),
          child: Column(
            children: List.generate(30, (index) {
              final stage = index + 1;
              final isUnlocked = stage <= unlockedLevel;
              final isCurrent = stage == unlockedLevel;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Material(
                  color: isUnlocked
                      ? (isCurrent ? const Color(0xFFE3D8FF) : const Color(0xFFF3EEFF))
                      : const Color(0xFFF1F1F5),
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: isUnlocked ? () => startGame(startingLevel: stage) : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isUnlocked ? const Color(0xFF6846D8) : Colors.grey.shade400,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              isUnlocked ? (stage == 1 ? Icons.castle_rounded : Icons.auto_awesome) : Icons.lock_rounded,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('مرحله ${fa('$stage')}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                                Text(
                                  isCurrent ? 'آخرین مرحله بازشده' : isUnlocked ? 'آماده ماجراجویی' : 'با پیشرفت در بازی باز می‌شود',
                                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                                ),
                              ],
                            ),
                          ),
                          Icon(isUnlocked ? Icons.play_circle_fill_rounded : Icons.lock_outline, color: isUnlocked ? const Color(0xFF6846D8) : Colors.grey),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: () => setState(() => showMap = false),
            icon: const Icon(Icons.home_rounded),
            label: const Text('بازگشت به خانه'),
            style: primaryButtonStyle(),
          ),
        ),
      ],
    );
  }

  Widget buildGame() {
    final compact = MediaQuery.sizeOf(context).height < 760;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF281052), Color(0xFF6846D8), Color(0xFF9875F5)],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(color: const Color(0xFF6846D8).withValues(alpha: 0.2), blurRadius: 18, offset: const Offset(0, 6)),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    key: const ValueKey('practice-back-button'),
                    onPressed: backFromPractice,
                    tooltip: selectedChapter == 2
                        ? 'بازگشت به مباحث فصل کسر'
                        : 'بازگشت به خانه',
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    style: IconButton.styleFrom(backgroundColor: Colors.white.withValues(alpha: 0.14)),
                  ),
                  const Spacer(),
                  Text(
                    selectedChapter == null
                        ? 'ماجراجویی ریاضی'
                        : selectedTopic == null
                            ? 'تمرین فصل ${fa('$selectedChapter')}'
                            : topicTitle(selectedTopic),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.auto_awesome_rounded, color: Colors.amberAccent),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _gameStat(icon: Icons.stars_rounded, label: 'امتیاز', value: fa('$score'))),
                  const SizedBox(width: 8),
                  Expanded(child: _gameStat(icon: Icons.flag_rounded, label: selectedChapter == null ? 'مرحله' : 'پاسخ درست', value: selectedChapter == null ? '${fa('$level')} از ۳۰' : fa('$questionInLevel'))),
                  const SizedBox(width: 8),
                  Expanded(child: _gameStat(icon: Icons.favorite_rounded, label: 'جان', value: '❤️' * lives)),
                ],
              ),
            ],
          ),
        ),
        if (selectedChapter == null) ...[
          SizedBox(height: compact ? 12 : 18),
          Container(
            padding: EdgeInsets.all(compact ? 15 : 22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: const Color(0xFFE5DDFB)),
              boxShadow: [
                BoxShadow(color: const Color(0xFF39246B).withValues(alpha: 0.06), blurRadius: 18, offset: const Offset(0, 5)),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(color: const Color(0xFFF0EBFF), borderRadius: BorderRadius.circular(14)),
                      child: const Icon(Icons.timer_rounded, color: Color(0xFF6846D8)),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(child: Text('زمان باقی‌مانده', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold))),
                    Text(
                      '${fa('$timeLeft')} ثانیه',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: timeLeft <= 7 ? Colors.red.shade700 : const Color(0xFF6846D8)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: LinearProgressIndicator(
                    value: (timeLeft / questionTimeLimit).clamp(0.0, 1.0).toDouble(),
                    minHeight: 8,
                    backgroundColor: const Color(0xFFEDE7F6),
                    color: timeLeft <= 7 ? Colors.redAccent : const Color(0xFF8A63EF),
                  ),
                ),
              ],
            ),
          ),
        ],
        SizedBox(height: compact ? 12 : 18),
        Container(
          padding: EdgeInsets.all(compact ? 15 : 22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: const Color(0xFFE5DDFB)),
            boxShadow: [
              BoxShadow(color: const Color(0xFF39246B).withValues(alpha: 0.06), blurRadius: 18, offset: const Offset(0, 5)),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFF0EBFF), Color(0xFFE0D5FF)]),
                  borderRadius: BorderRadius.circular(22),
                ),
                alignment: Alignment.center,
                child: const Text('🧠', style: TextStyle(fontSize: 40)),
              ),
              const SizedBox(height: 10),
              const Text('جواب درست را انتخاب کن', style: TextStyle(fontSize: 14, color: Colors.black54, fontWeight: FontWeight.w600)),
              if (isRemedialPractice) ...[
                const SizedBox(height: 6),
                Container(
                  key: const ValueKey('remedial-practice-banner'),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F8EE),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'تمرین جبرانی • بدون امتیاز و کاهش جان',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF176B3A),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
              if (currentQuestion != null) ...[
                const SizedBox(height: 4),
                Text(currentQuestion!.topic, style: const TextStyle(fontSize: 13, color: Color(0xFF6846D8), fontWeight: FontWeight.w800)),
              ],
              if (currentQuestion?.fractionVisual case final visual?) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F6FF),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE5DDFB)),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'نمایش شکل کسر',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF665A83),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildFractionVisual(visual),
                    ],
                  ),
                ),
              ],
              if (currentQuestion?.fractionNumberLine case final line?) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F6FF),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE5DDFB)),
                  ),
                  child: _buildInteractiveNumberLine(line),
                ),
              ],
              SizedBox(height: compact ? 8 : 14),
              Directionality(
                textDirection: selectedChapter == null ? TextDirection.ltr : TextDirection.rtl,
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(vertical: compact ? 14 : 20, horizontal: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F6FF),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE5DDFB)),
                  ),
                  child: Text(
                    question,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: compact ? (question.length > 90 ? 18 : question.length > 55 ? 23 : 32) : (question.length > 90 ? 21 : question.length > 55 ? 29 : 38), fontWeight: FontWeight.w900, color: const Color(0xFF39246B)),
                  ),
                ),
              ),
              SizedBox(height: compact ? 16 : 22),
              if (currentQuestion?.fractionNumberLine == null)
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: compact ? 2.0 : 1.9,
                  children: options.map((option) {
                    final isCorrect = answered && option == correctAnswer;
                    final isWrong =
                        answered && option == selectedAnswer && option != correctAnswer;
                    final background = isCorrect
                        ? const Color(0xFFD8F7E3)
                        : isWrong
                            ? const Color(0xFFFFE0E3)
                            : const Color(0xFFF1EDFF);
                    final foreground = isCorrect
                        ? const Color(0xFF176B3A)
                        : isWrong
                            ? const Color(0xFFB42332)
                            : const Color(0xFF39246B);
                    return ElevatedButton(
                      onPressed: answered ? null : () => answerQuestion(option),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: background,
                        disabledBackgroundColor: background,
                        foregroundColor: foreground,
                        disabledForegroundColor: foreground,
                        elevation: 0,
                        padding: const EdgeInsets.all(8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                          side: BorderSide(
                            color: isCorrect
                                ? const Color(0xFF65C98A)
                                : isWrong
                                    ? const Color(0xFFEF8A95)
                                    : const Color(0xFFE1D7FF),
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (isCorrect) ...[
                            const Icon(Icons.check_circle_rounded, size: 19),
                            const SizedBox(width: 5),
                          ] else if (isWrong) ...[
                            const Icon(Icons.cancel_rounded, size: 19),
                            const SizedBox(width: 5),
                          ],
                          Flexible(
                            child: Text(
                              fa(option),
                              style: TextStyle(
                                fontSize: compact ? 24 : 27,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              if (answered) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: selectedAnswer == correctAnswer ? const Color(0xFFE8F8EE) : const Color(0xFFFFF0F1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    selectedAnswer == correctAnswer
                        ? '🎉 آفرین! جواب درست بود.'
                        : timedOut
                            ? '⏰ وقت تمام شد! جواب ${fa(correctAnswer)} بود.'
                            : '💪 جواب درست ${fa(correctAnswer)} بود.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: selectedAnswer == correctAnswer ? const Color(0xFF176B3A) : const Color(0xFFB42332)),
                  ),
                ),
                if (currentQuestion != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    answerFeedbackText(
                      question: currentQuestion!,
                      selectedAnswer: selectedAnswer,
                      timedOut: timedOut,
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF665A83), height: 1.5),
                  ),
                ],
                if (!gameOver &&
                    selectedChapter == 2 &&
                    selectedTopic != null &&
                    !isRemedialPractice &&
                    selectedAnswer != null &&
                    selectedAnswer != correctAnswer) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      key: const ValueKey('remedial-practice-button'),
                      onPressed: startRemedialPractice,
                      icon: const Icon(Icons.psychology_alt_rounded),
                      label: const Text(
                        'تمرین بیشتر از همین مبحث',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
                if (!gameOver) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: nextQuestion,
                      icon: const Icon(Icons.arrow_back_rounded),
                      label: const Text('سؤال بعدی', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                      style: primaryButtonStyle(),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
        SizedBox(height: compact ? 10 : 14),
        Row(
          children: [
            const Icon(Icons.bolt_rounded, color: Color(0xFF6846D8), size: 20),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                selectedChapter == null
                    ? 'پاسخ‌های درست این مرحله: ${fa('$questionInLevel')} از ۵'
                    : 'پاسخ‌های درست در تمرین: ${fa('$questionInLevel')}',
                style: const TextStyle(fontSize: 13, color: Color(0xFF665A83), fontWeight: FontWeight.w600),
              ),
            ),
            Text(rankNames[rankIndex], style: const TextStyle(fontSize: 12, color: Color(0xFF6846D8), fontWeight: FontWeight.w900)),
          ],
        ),
      ],
    );
  }

  Widget _buildFractionVisual(FractionVisual visual) {
    switch (visual.style) {
      case FractionVisualStyle.bar:
        return SizedBox(
          height: 42,
          child: Row(
            children: List.generate(
              visual.parts,
              (index) => Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: index < visual.filled
                        ? const Color(0xFF55B879)
                        : Colors.white,
                    border: Border.all(
                      color: const Color(0xFF39246B),
                      width: 1.2,
                    ),
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ),
            ),
          ),
        );
      case FractionVisualStyle.grid:
        return Wrap(
          alignment: WrapAlignment.center,
          spacing: 5,
          runSpacing: 5,
          children: List.generate(
            visual.parts,
            (index) => Container(
              width: visual.parts > 6 ? 30 : 38,
              height: visual.parts > 6 ? 30 : 38,
              decoration: BoxDecoration(
                color: index < visual.filled
                    ? const Color(0xFF55B879)
                    : Colors.white,
                border: Border.all(
                  color: const Color(0xFF39246B),
                  width: 1.2,
                ),
                borderRadius: BorderRadius.circular(5),
              ),
            ),
          ),
        );
      case FractionVisualStyle.circle:
        return CustomPaint(
          size: const Size(132, 132),
          painter: FractionCirclePainter(
            parts: visual.parts,
            filled: visual.filled,
          ),
        );
    }
  }

  Widget _buildInteractiveNumberLine(FractionNumberLineVisual visual) {
    final selectedIndex = selectedAnswer == null
        ? null
        : visual.tickValues.indexOf(selectedAnswer!);
    return Column(
      children: [
        const Text(
          'از صفر تا یک؛ محل کسر را روی یکی از نقطه‌ها لمس کن',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF665A83),
          ),
        ),
        const SizedBox(height: 7),
        SizedBox(
          height: 62,
          width: double.infinity,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: answered
                    ? null
                    : (details) {
                        final usableWidth = max(1.0, constraints.maxWidth - 28);
                        final rawIndex = ((details.localPosition.dx - 14) /
                                usableWidth *
                                visual.divisions)
                            .round();
                        final index = rawIndex
                            .clamp(0, visual.divisions)
                            .toInt();
                        answerQuestion(visual.tickValues[index]);
                      },
                child: CustomPaint(
                  size: Size(constraints.maxWidth, 62),
                  painter: FractionNumberLinePainter(
                    divisions: visual.divisions,
                    selectedIndex: selectedIndex,
                    correctIndex: answered ? visual.numerator : null,
                  ),
                ),
              );
            },
          ),
        ),
        Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            children: List.generate(
              visual.tickValues.length,
              (index) => Expanded(
                child: Text(
                  fa(visual.tickValues[index]),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.visible,
                  style: TextStyle(
                    fontSize: visual.divisions > 6 ? 9 : 10,
                    color: selectedIndex == index
                        ? const Color(0xFF39246B)
                        : const Color(0xFF665A83),
                    fontWeight: selectedIndex == index
                        ? FontWeight.w900
                        : FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _gameStat({required IconData icon, required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 19),
          const SizedBox(height: 4),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 11)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  Widget buildGameOver() {
    final medal = score >= 150
        ? '🥇'
        : score >= 80
            ? '🥈'
            : '🥉';

    return Container(
      padding: const EdgeInsets.all(26),
      decoration: cardDecoration(),
      child: Column(
        children: [
          const Text('🏁', style: TextStyle(fontSize: 65)),
          const SizedBox(height: 12),
          const Text(
            'بازی تمام شد!',
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          Text(medal, style: const TextStyle(fontSize: 65)),
          Text(
            score >= 150
                ? 'فوق‌العاده بودی، قهرمان!'
                : score >= 80
                    ? 'آفرین! خیلی خوب پیش رفتی.'
                    : 'تلاش خوبی بود؛ دوباره امتحان کن!',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 19),
          ),
          const SizedBox(height: 22),
          resultRow('امتیاز این دور', fa('$score')),
          resultRow('مرحله رسیده‌شده', fa('$level')),
          resultRow('رتبهٔ فعلی', rankNames[rankIndex]),
          resultRow('امتیاز کل', fa('$totalScore')),
          resultRow('بهترین امتیاز', fa('$bestScore')),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: () => startGame(
                chapter: selectedChapter,
                topic: selectedTopic,
              ),
              icon: const Icon(Icons.replay_rounded),
              label: const Text('بازی دوباره', style: TextStyle(fontSize: 19)),
              style: primaryButtonStyle(),
            ),
          ),
          TextButton(
            onPressed: goHome,
            child: const Text('صفحه شروع'),
          ),
        ],
      ),
    );
  }

  Widget resultRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 17)),
          Text(
            value,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget smallInfo(String title, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 5),
      decoration: cardDecoration(),
      child: Column(
        children: [
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  BoxDecoration cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      boxShadow: [
        BoxShadow(
          color: Colors.deepPurple.withValues(alpha: 0.07),
          blurRadius: 18,
          offset: const Offset(0, 5),
        ),
      ],
    );
  }

  ButtonStyle primaryButtonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF6846D8),
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      elevation: 2,
    );
  }
}


class FractionCirclePainter extends CustomPainter {
  const FractionCirclePainter({
    required this.parts,
    required this.filled,
  });

  final int parts;
  final int filled;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final border = Paint()
      ..color = const Color(0xFF39246B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (var index = 0; index < parts; index++) {
      final start = -pi / 2 + index * 2 * pi / parts;
      final sweep = 2 * pi / parts;
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..arcTo(rect, start, sweep, false)
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..color = index < filled
              ? const Color(0xFF55B879)
              : Colors.white,
      );
      canvas.drawPath(path, border);
    }
  }

  @override
  bool shouldRepaint(covariant FractionCirclePainter oldDelegate) =>
      oldDelegate.parts != parts || oldDelegate.filled != filled;
}

class FractionNumberLinePainter extends CustomPainter {
  const FractionNumberLinePainter({
    required this.divisions,
    required this.selectedIndex,
    required this.correctIndex,
  });

  final int divisions;
  final int? selectedIndex;
  final int? correctIndex;

  @override
  void paint(Canvas canvas, Size size) {
    const start = 14.0;
    const endPadding = 14.0;
    final end = size.width - endPadding;
    final y = size.height / 2 - 3;
    final axisPaint = Paint()
      ..color = const Color(0xFF39246B)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final tickPaint = Paint()
      ..color = const Color(0xFF665A83)
      ..strokeWidth = 1.6;

    canvas.drawLine(Offset(start, y), Offset(end, y), axisPaint);
    for (var index = 0; index <= divisions; index++) {
      final x = start + (end - start) * index / divisions;
      canvas.drawLine(
        Offset(x, y - 9),
        Offset(x, y + 9),
        tickPaint,
      );
      canvas.drawCircle(
        Offset(x, y),
        3.2,
        Paint()..color = const Color(0xFF6846D8),
      );
    }

    if (correctIndex != null) {
      final x = start + (end - start) * correctIndex! / divisions;
      canvas.drawCircle(
        Offset(x, y),
        8,
        Paint()..color = const Color(0xFF55B879),
      );
      canvas.drawCircle(
        Offset(x, y),
        3,
        Paint()..color = Colors.white,
      );
    }

    if (selectedIndex != null && selectedIndex! >= 0) {
      final x = start + (end - start) * selectedIndex! / divisions;
      final isCorrect = selectedIndex == correctIndex;
      canvas.drawCircle(
        Offset(x, y),
        8,
        Paint()
          ..color = isCorrect
              ? const Color(0xFF55B879)
              : correctIndex == null
                  ? const Color(0xFF6846D8)
                  : const Color(0xFFE05B64),
      );
      canvas.drawCircle(
        Offset(x, y),
        3,
        Paint()..color = Colors.white,
      );
    }
  }

  @override
  bool shouldRepaint(covariant FractionNumberLinePainter oldDelegate) =>
      oldDelegate.divisions != divisions ||
      oldDelegate.selectedIndex != selectedIndex ||
      oldDelegate.correctIndex != correctIndex;
}
