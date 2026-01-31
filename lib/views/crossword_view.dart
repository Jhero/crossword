import 'dart:async';
import 'package:flutter/material.dart';
import '../presenters/crossword_presenter.dart';
import '../models/crossword_model.dart';
import '../utils/score_manager.dart';

class CrosswordView extends StatefulWidget {
  final CrosswordPresenter presenter;

  const CrosswordView({super.key, required this.presenter});

  @override
  State<CrosswordView> createState() => _CrosswordViewState();
}

class _CrosswordViewState extends State<CrosswordView> {
  final Map<String, TextEditingController> controllers = {};
  final Map<String, FocusNode> focusNodes = {};
  final Map<String, Color> boxColors = {};
  CrosswordQuestion? highlightedQuestion;
  CrosswordQuestion? activeQuestion;
  int correctCount = 0;
  int totalCells = 0;

  // Timer
  int remainingSeconds = 600; // 10 menit
  Timer? gameTimer;

  @override
  void initState() {
    super.initState();
    totalCells = widget.presenter.totalCells();
    startTimer();
  }

  @override
  void dispose() {
    for (var c in controllers.values) {
      c.dispose();
    }
    for (var f in focusNodes.values) {
      f.dispose();
    }
    gameTimer?.cancel();
    super.dispose();
  }

  void startTimer() {
    gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (remainingSeconds > 0) {
        setState(() {
          remainingSeconds--;
        });
      } else {
        timer.cancel();
        showTimeUpDialog();
      }
    });
  }

  void showCompletionDialog() {
    // Save score
    final scoreManager = ScoreManager();
    // Calculate score based on remaining time or just fixed 100
    // Example: 100 points + remaining seconds
    int score = 100 + remainingSeconds; 
    scoreManager.saveScore(widget.presenter.model.id, score);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Selamat!"),
          content: Text("Semua jawaban benar 🎉\nSkor Anda: $score"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pop(true); // Return to LevelView with result
              },
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
  }

  void showTimeUpDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Waktu Habis ⏰"),
          content: const Text("Sayang sekali, waktu permainan sudah habis."),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                resetGame();
              },
              child: const Text("Mulai Ulang"),
            ),
          ],
        );
      },
    );
  }

  void resetGame() {
    setState(() {
      for (var c in controllers.values) {
        c.clear();
      }
      for (var key in boxColors.keys) {
        boxColors[key] = Colors.white;
      }
      correctCount = 0;
      highlightedQuestion = null;
      activeQuestion = null;
      remainingSeconds = 600;
    });
    gameTimer?.cancel();
    startTimer();
  }

  void highlightQuestion(CrosswordQuestion q) {
    setState(() {
      highlightedQuestion = q;
      activeQuestion = q;
    });
  }

  void moveToNextCell(CrosswordQuestion question, int row, int col) {
    int nextRow = row;
    int nextCol = col;

    if (question.isAcross) {
      nextCol++;
      if (nextCol >= question.col + question.answer.length) return;
    } else {
      nextRow++;
      if (nextRow >= question.row + question.answer.length) return;
    }

    String nextKey = "$nextRow-$nextCol";
    if (focusNodes.containsKey(nextKey)) {
      FocusScope.of(context).requestFocus(focusNodes[nextKey]);
    }
  }

  void updateProgress() {
    int count = 0;
    for (var q in widget.presenter.model.questions) {
      for (int i = 0; i < q.answer.length; i++) {
        int row = q.isAcross ? q.row : q.row + i;
        int col = q.isAcross ? q.col + i : q.col;
        String key = "$row-$col";
        if (controllers[key]?.text.toUpperCase() == q.answer[i].toUpperCase()) {
          count++;
        }
      }
    }
    setState(() {
      correctCount = count;
    });

    if (correctCount == totalCells) {
      showCompletionDialog();
    }
  }

  @override
  Widget build(BuildContext context) {
      double progress = totalCells > 0 ? correctCount / totalCells : 0;
      String minutes = (remainingSeconds ~/ 60).toString().padLeft(2, '0');
      String seconds = (remainingSeconds % 60).toString().padLeft(2, '0');

      return Scaffold(
        appBar: AppBar(
          title: Text(widget.presenter.model.title),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF1488CC), // Modern Blue
                      Color(0xFF2B32B2), // Deep Purple/Blue
                    ],
                  ),
                ),
              ),
            ),
            Column(
              children: [
                // Progress bar + Timer + Reset
                Container(
                  margin: const EdgeInsets.all(12.0),
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: progress,
                                backgroundColor: Colors.grey.shade300,
                                color: Colors.blueAccent,
                                minHeight: 12,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "Progress: ${(progress * 100).toStringAsFixed(0)}%",
                              style: const TextStyle(
                                fontSize: 16, 
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: remainingSeconds < 60 ? Colors.red.shade100 : Colors.blue.shade100,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              "$minutes:$seconds",
                              style: TextStyle(
                                fontSize: 20, 
                                fontWeight: FontWeight.bold,
                                color: remainingSeconds < 60 ? Colors.red : Colors.blue.shade900,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          ElevatedButton.icon(
                            onPressed: resetGame,
                            icon: const Icon(Icons.refresh, size: 16),
                            label: const Text("Reset"),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Center(
                    child: GridView.builder(
                      shrinkWrap: true,
                      itemCount: 15 * 15,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 15,
                      ),
                      itemBuilder: (context, index) {
                        int row = index ~/ 15;
                        int col = index % 15;

                        CrosswordQuestion? question = widget.presenter.findQuestion(row, col);
                        bool isActive = question != null;

                        if (!isActive) {
                          return Container(
                            margin: const EdgeInsets.all(1),
                            color: Colors.black,
                          );
                        }

                        String key = "$row-$col";
                        controllers.putIfAbsent(key, () => TextEditingController());
                        focusNodes.putIfAbsent(key, () => FocusNode());
                        boxColors.putIfAbsent(key, () => Colors.white);

                        bool isHighlighted = false;
                        if (highlightedQuestion != null) {
                          if (highlightedQuestion!.isAcross &&
                              highlightedQuestion!.row == row &&
                              col >= highlightedQuestion!.col &&
                              col < highlightedQuestion!.col + highlightedQuestion!.answer.length) {
                            isHighlighted = true;
                          } else if (!highlightedQuestion!.isAcross &&
                              highlightedQuestion!.col == col &&
                              row >= highlightedQuestion!.row &&
                              row < highlightedQuestion!.row + highlightedQuestion!.answer.length) {
                            isHighlighted = true;
                          }
                        }

                        // Cek apakah kotak ini adalah awal dari sebuah kata (untuk menampilkan nomor)
                        int? questionNumber;
                        // Kita cari apakah ada question yang dimulai di (row, col)
                        // Karena satu kotak bisa jadi awal dari Across dan Down, kita prioritaskan tampilkan nomor.
                        // Biasanya nomornya sama jika memang berpotongan di awal.
                        // Namun di data kita, number adalah properti question.
                        
                        // Cari question yang dimulai di sini
                        try {
                          var startQ = widget.presenter.model.questions.firstWhere(
                            (q) => q.row == row && q.col == col,
                          );
                          questionNumber = startQ.number;
                        } catch (_) {}

                        return Container(
                          margin: const EdgeInsets.all(1),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.black54),
                            color: isHighlighted
                                ? Colors.blue.shade100
                                : boxColors[key],
                          ),
                          child: Stack(
                            children: [
                              TextField(
                                controller: controllers[key],
                                focusNode: focusNodes[key],
                                textAlign: TextAlign.center,
                                maxLength: 1,
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                decoration: const InputDecoration(
                                  counterText: '',
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.only(bottom: 8), 
                                ),
                                onTap: () {
                                  setState(() {
                                    activeQuestion = question;
                                    highlightQuestion(question!);
                                  });
                                },
                                onChanged: (val) {
                                  if (val.isNotEmpty) {
                                    String input = val.toUpperCase();
                                    controllers[key]!.text = input;
                                    controllers[key]!.selection = TextSelection.collapsed(offset: 1);

                                    bool correct = widget.presenter.validateLetter(question!, row, col, input);
                                    setState(() {
                                      boxColors[key] = correct ? Colors.green.shade200 : Colors.red.shade200;
                                      activeQuestion = question;
                                    });

                                    if (highlightedQuestion != null &&
                                        highlightedQuestion!.number == question.number) {
                                      moveToNextCell(question, row, col);
                                    }

                                    updateProgress();
                                  }
                                },
                              ),
                              if (questionNumber != null)
                                Positioned(
                                  top: 2,
                                  left: 4,
                                  child: Text(
                                    "$questionNumber",
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
                Expanded(
                flex: 1,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  color: Colors.white.withOpacity(0.9),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "MENDATAR",
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                            ),
                            const Divider(),
                            Expanded(
                              child: ListView(
                                children: widget.presenter.getAcrossQuestions().map((q) {
                                  bool isSelected = highlightedQuestion == q;
                                  return GestureDetector(
                                    onTap: () => highlightQuestion(q),
                                    child: Container(
                                      color: isSelected ? Colors.blue.withOpacity(0.2) : Colors.transparent,
                                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                                      child: Text(
                                        "${q.number}. ${q.clue}",
                                        style: TextStyle(
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "MENURUN",
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                            ),
                            const Divider(),
                            Expanded(
                              child: ListView(
                                children: widget.presenter.getDownQuestions().map((q) {
                                  bool isSelected = highlightedQuestion == q;
                                  return GestureDetector(
                                    onTap: () => highlightQuestion(q),
                                    child: Container(
                                      color: isSelected ? Colors.blue.withOpacity(0.2) : Colors.transparent,
                                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                                      child: Text(
                                        "${q.number}. ${q.clue}",
                                        style: TextStyle(
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
