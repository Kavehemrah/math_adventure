
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final Random random = Random();

  Timer? timer;
  int bestScore = 0;
  int unlockedLevel = 1;
  int score = 0;
  int level = 1;
  int lives = 3;
  int timeLeft = 25;
  int questionInLevel = 0;
  int correctAnswer = 0;
  int? selectedAnswer;

  String question = '';
  String operationName = '';
  List<int> options = [];

  bool answered = false;
  bool gameStarted = false;
  bool showMap = false;
  bool gameOver = false;
  bool timedOut = false;

  @override
  void initState() {
    super.initState();
    loadBestScore();
  }

  Future<void> loadBestScore() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      bestScore = prefs.getInt('best_score') ?? 0;
      unlockedLevel = max(1, prefs.getInt('unlocked_level') ?? 1);
    });
  }

  Future<void> saveBestScore() async {
    if (score <= bestScore) return;
    bestScore = score;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('best_score', bestScore);
  }

  Future<void> saveUnlockedLevel() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('unlocked_level', unlockedLevel);
  }

  void startGame({int? startingLevel}) {
    timer?.cancel();
    setState(() {
      score = 0;
      level = startingLevel ?? 1;
      lives = 3;
      questionInLevel = 0;
      gameStarted = true;
      showMap = false;
      gameOver = false;
      createQuestion();
    });
    startTimer();
  }

  void startTimer() {
    timer?.cancel();
    timeLeft = 25;
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

    int a;
    int b;
    int result;
    String op;

    final List<String> operations = level <= 2
        ? ['+', '-']
        : level <= 4
            ? ['+', '-', '×']
            : ['+', '-', '×', '÷'];

    op = operations[random.nextInt(operations.length)];

    if (level <= 2) {
      a = random.nextInt(20) + 1;
      b = random.nextInt(20) + 1;
    } else if (level <= 4) {
      a = random.nextInt(50) + 10;
      b = random.nextInt(20) + 1;
    } else if (level <= 7) {
      a = random.nextInt(90) + 10;
      b = random.nextInt(12) + 2;
    } else {
      a = random.nextInt(150) + 20;
      b = random.nextInt(15) + 2;
    }

    if (op == '-' && b > a) {
      final temp = a;
      a = b;
      b = temp;
    }

    if (op == '÷') {
      result = random.nextInt(min(level + 5, 15)) + 2;
      b = random.nextInt(10) + 2;
      a = result * b;
    } else if (op == '×') {
      if (level <= 4) {
        a = random.nextInt(12) + 2;
        b = random.nextInt(10) + 2;
      }
      result = a * b;
    } else if (op == '+') {
      result = a + b;
    } else {
      result = a - b;
    }

    correctAnswer = result;
    question = '${fa('$a')} $op ${fa('$b')} = ؟';

    final Set<int> choices = {result};
    while (choices.length < 4) {
      final offset = random.nextInt(15) - 7;
      final candidate = result + (offset == 0 ? 9 : offset);
      if (candidate >= 0 && candidate != result) {
        choices.add(candidate);
      }
    }

    options = choices.toList()..shuffle(random);
  }

  void answerQuestion(int? value) {
    if (answered || gameOver) return;

    timer?.cancel();
    HapticFeedback.selectionClick();

    setState(() {
      answered = true;
      selectedAnswer = value;
      timedOut = value == null;

      if (value == correctAnswer) {
        score += 10 + max(0, timeLeft ~/ 5);
        questionInLevel++;
        SystemSound.play(SystemSoundType.click);

        if (questionInLevel >= 5) {
          level++;
          if (level > unlockedLevel) {
            unlockedLevel = level;
            saveUnlockedLevel();
          }
          questionInLevel = 0;
        }
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

  void nextQuestion() {
    if (gameOver) return;
    setState(createQuestion);
    startTimer();
  }

  void goHome() {
    timer?.cancel();
    setState(() {
      gameStarted = false;
      showMap = false;
      gameOver = false;
    });
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
          'مرحله‌های بازشده: ${fa('$unlockedLevel')} از ۱۰',
          style: const TextStyle(fontSize: 16, color: Colors.black54),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: cardDecoration(),
          child: Column(
            children: List.generate(10, (index) {
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
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: smallInfo('🏆 امتیاز', fa('$score'))),
            const SizedBox(width: 8),
            Expanded(child: smallInfo('⭐ مرحله', fa('$level'))),
            const SizedBox(width: 8),
            Expanded(child: smallInfo('❤️ جان', fa('$lives'))),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: cardDecoration(),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '⏱️ زمان پاسخ',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${fa('$timeLeft')} ثانیه',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: timeLeft <= 7 ? Colors.red : Colors.deepPurple,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: LinearProgressIndicator(
                  value: timeLeft / 25,
                  minHeight: 9,
                  backgroundColor: Colors.deepPurple.shade50,
                  color: timeLeft <= 7 ? Colors.red : Colors.deepPurple,
                ),
              ),
              const SizedBox(height: 28),
              const Text('🧠', style: TextStyle(fontSize: 46)),
              const SizedBox(height: 10),
              Text(
                question,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF39246B),
                ),
              ),
              const SizedBox(height: 28),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.8,
                children: options.map((option) {
                  Color color = const Color(0xFFEDE7F6);
                  Color textColor = const Color(0xFF39246B);

                  if (answered && option == correctAnswer) {
                    color = const Color(0xFFC8E6C9);
                    textColor = Colors.green.shade900;
                  } else if (answered && option == selectedAnswer) {
                    color = const Color(0xFFFFCDD2);
                    textColor = Colors.red.shade900;
                  }

                  return ElevatedButton(
                    onPressed: answered ? null : () => answerQuestion(option),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      disabledBackgroundColor: color,
                      foregroundColor: textColor,
                      disabledForegroundColor: textColor,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: Text(
                      fa('$option'),
                      style: const TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 22),
              if (answered) ...[
                Text(
                  selectedAnswer == correctAnswer
                      ? '🎉 آفرین! جواب درست بود.'
                      : timedOut
                          ? '⏰ وقت تمام شد! جواب ${fa('$correctAnswer')} بود.'
                          : '💪 جواب درست ${fa('$correctAnswer')} بود.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: selectedAnswer == correctAnswer
                        ? Colors.green.shade700
                        : Colors.red.shade700,
                  ),
                ),
                const SizedBox(height: 16),
                if (!gameOver)
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: nextQuestion,
                      style: primaryButtonStyle(),
                      child: const Text(
                        'سؤال بعدی  ←',
                        style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                      ),
                    ),
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: () => setState(() {
                        gameStarted = false;
                        gameOver = true;
                      }),
                      style: primaryButtonStyle(),
                      child: const Text('دیدن نتیجه'),
                    ),
                  ),
              ],
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: goHome,
                icon: const Icon(Icons.home_rounded),
                label: const Text('بازگشت به خانه'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'پاسخ درست در این مرحله: ${fa('$questionInLevel')} از ۵',
          style: const TextStyle(fontSize: 15, color: Colors.black54),
        ),
      ],
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
          resultRow('امتیاز نهایی', fa('$score')),
          resultRow('مرحله رسیده‌شده', fa('$level')),
          resultRow('بهترین امتیاز', fa('$bestScore')),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: startGame,
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
