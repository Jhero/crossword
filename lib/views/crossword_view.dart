import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final ScoreManager _scoreManager = ScoreManager();
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

  void moveToPreviousCell(int row, int col) {
    if (activeQuestion == null) return;

    int prevRow = row;
    int prevCol = col;

    if (activeQuestion!.isAcross) {
      prevCol--;
    } else {
      prevRow--;
    }

    // Check if prev cell is valid within the active question
    bool isValid = false;
    if (activeQuestion!.isAcross) {
      if (prevCol >= activeQuestion!.col && prevCol < activeQuestion!.col + activeQuestion!.answer.length) {
        isValid = true;
      }
    } else {
      if (prevRow >= activeQuestion!.row && prevRow < activeQuestion!.row + activeQuestion!.answer.length) {
        isValid = true;
      }
    }

    if (isValid) {
      String prevKey = "$prevRow-$prevCol";
      if (focusNodes.containsKey(prevKey)) {
        FocusScope.of(context).requestFocus(focusNodes[prevKey]);
        // Clear the previous cell content
        if (controllers[prevKey]!.text.isNotEmpty) {
           controllers[prevKey]!.clear();
           // Update color and progress since we cleared a cell
           boxColors[prevKey] = Colors.white;
           updateProgress();
        }
      }
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

  Widget _buildActionButton(IconData icon, {String? badge, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.deepOrange,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          if (badge != null)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  badge,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
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
                // New Top Bar Layout
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  child: Row(
                    children: [
                      // Progress Star
                      SizedBox(
                        width: 56,
                        height: 56,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: Colors.deepOrange,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.star, color: Colors.white, size: 28),
                            ),
                            SizedBox(
                              width: 56,
                              height: 56,
                              child: CircularProgressIndicator(
                                value: progress,
                                strokeWidth: 4,
                                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const Spacer(),

                      // Timer
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
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

                      const Spacer(),

                      // Action Buttons
                      _buildActionButton(Icons.auto_fix_high, badge: "1", onTap: () {
                         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Fitur Bantuan segera hadir!")));
                      }),
                      const SizedBox(width: 12),
                      _buildActionButton(Icons.search, badge: "1", onTap: () {
                         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Fitur Cari segera hadir!")));
                      }),
                      const SizedBox(width: 12),
                      _buildActionButton(Icons.refresh, onTap: resetGame),
                    ],
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return InteractiveViewer(
                        boundaryMargin: const EdgeInsets.all(500),
                        minScale: 0.1,
                        maxScale: 5.0,
                        constrained: false,
                        child: SizedBox(
                          width: 1000,
                          height: 1000,
                          child: GridView.builder(
                            physics: const NeverScrollableScrollPhysics(),
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
                                    color: Colors.transparent,
                                  );
                                }

                                String key = "$row-$col";
                                controllers.putIfAbsent(key, () => TextEditingController());
                                focusNodes.putIfAbsent(key, () {
                                  final node = FocusNode();
                                  node.onKeyEvent = (FocusNode node, KeyEvent event) {
                                    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.backspace) {
                                      if (controllers[key]!.text.isEmpty) {
                                        moveToPreviousCell(row, col);
                                        return KeyEventResult.handled;
                                      }
                                    }
                                    return KeyEventResult.ignored;
                                  };
                                  return node;
                                });
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

                                int? questionNumber;
                                try {
                                  var startQ = widget.presenter.model.questions.firstWhere(
                                    (q) => q.row == row && q.col == col,
                                  );
                                  questionNumber = startQ.number;
                                } catch (_) {}

                                Color cellColor;
                                Color textColor;

                                if (boxColors[key] != Colors.white) {
                                  cellColor = boxColors[key]!;
                                  textColor = Colors.white;
                                } else if (controllers[key]!.text.isNotEmpty) {
                                  cellColor = const Color(0xFF0D47A1); // Dark Blue for filled
                                  textColor = Colors.white;
                                } else {
                                  cellColor = Colors.white.withOpacity(0.8);
                                  textColor = Colors.black;
                                }

                                return Container(
                                  margin: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: isHighlighted 
                                        ? Border.all(color: Colors.amber, width: 3) 
                                        : null,
                                    color: cellColor,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 4,
                                        offset: const Offset(2, 2),
                                      ),
                                    ],
                                  ),
                                  child: Stack(
                                    children: [
                                      TextField(
                                        controller: controllers[key],
                                        focusNode: focusNodes[key],
                                        textAlign: TextAlign.center,
                                        maxLength: 1,
                                        style: TextStyle(
                                          fontSize: 32, 
                                          fontWeight: FontWeight.bold,
                                          color: textColor,
                                        ),
                                        decoration: const InputDecoration(
                                          counterText: '',
                                          border: InputBorder.none,
                                          contentPadding: EdgeInsets.symmetric(vertical: 10), 
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
                                              boxColors[key] = correct ? Colors.green : Colors.red;
                                              activeQuestion = question;
                                            });

                                            if (highlightedQuestion != null &&
                                                highlightedQuestion!.number == question.number) {
                                              moveToNextCell(question, row, col);
                                            }
                                          } else {
                                            setState(() {
                                              boxColors[key] = Colors.white;
                                            });
                                          }
                                          updateProgress();
                                        },
                                      ),
                                      if (questionNumber != null)
                                        Positioned(
                                          top: 4,
                                          left: 6,
                                          child: Text(
                                            "$questionNumber",
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: textColor == Colors.white ? Colors.white70 : Colors.black54,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      },
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
