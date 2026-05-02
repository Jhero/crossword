import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../models/crossword_model.dart';
import '../presenters/crossword_presenter.dart';
import '../utils/score_manager.dart';
import '../widgets/game_action_button.dart';
import '../widgets/game_progress_star.dart';
import '../widgets/game_timer_display.dart';

enum _Direction { across, down }

enum _WordMark { neutral, correct, wrong }

class _QuestionVm {
  final String id;
  final int number;
  final String clue;
  final String answer;
  final _Direction direction;
  final int startRow;
  final int startCol;
  final List<int> cellIndexes;

  const _QuestionVm({
    required this.id,
    required this.number,
    required this.clue,
    required this.answer,
    required this.direction,
    required this.startRow,
    required this.startCol,
    required this.cellIndexes,
  });
}

class _CellVm {
  final bool isBlock;
  final String value;
  final bool isHighlighted;
  final bool isCursor;
  final int? number;
  final _WordMark mark;

  const _CellVm({
    required this.isBlock,
    required this.value,
    required this.isHighlighted,
    required this.isCursor,
    required this.number,
    required this.mark,
  });

  _CellVm copyWith({
    bool? isBlock,
    String? value,
    bool? isHighlighted,
    bool? isCursor,
    int? number,
    _WordMark? mark,
    bool numberToNull = false,
  }) {
    return _CellVm(
      isBlock: isBlock ?? this.isBlock,
      value: value ?? this.value,
      isHighlighted: isHighlighted ?? this.isHighlighted,
      isCursor: isCursor ?? this.isCursor,
      number: numberToNull ? null : (number ?? this.number),
      mark: mark ?? this.mark,
    );
  }
}

class _CrosswordController {
  final int gridSize;
  final List<_QuestionVm> across;
  final List<_QuestionVm> down;

  final List<ValueNotifier<_CellVm>> cells;
  final ValueNotifier<List<String>> letterOptions;
  final ValueNotifier<String> activeClue;
  final ValueNotifier<String?> activeQuestionId;

  final Map<String, _QuestionVm> _questionsById;
  final Map<int, List<String>> _questionIdsByCell;
  final Map<int, String> _expectedLetterByCell;
  final Map<int, String> _userInput;
  final Map<String, _WordMark> _wordMarks;
  final Map<String, List<String>> _keyboardBaseByQuestionId;

  final Random _random;
  Future<void> _dispatchQueue = Future.value();

  String? _cursorQuestionId;
  int? _cursorCellIndex;

  _CrosswordController._({
    required this.gridSize,
    required this.across,
    required this.down,
    required this.cells,
    required this.letterOptions,
    required this.activeClue,
    required this.activeQuestionId,
    required Map<String, _QuestionVm> questionsById,
    required Map<int, List<String>> questionIdsByCell,
    required Map<int, String> expectedLetterByCell,
    required Map<int, String> userInput,
    required Map<String, _WordMark> wordMarks,
    required Map<String, List<String>> keyboardBaseByQuestionId,
    required Random random,
  })  : _questionsById = questionsById,
        _questionIdsByCell = questionIdsByCell,
        _expectedLetterByCell = expectedLetterByCell,
        _userInput = userInput,
        _wordMarks = wordMarks,
        _keyboardBaseByQuestionId = keyboardBaseByQuestionId,
        _random = random;

  static _CrosswordController fromLevel(LevelModel level, {int gridSize = 15}) {
    final normalizedQuestions = _normalizeQuestions(level.questions, gridSize);
    final byId = <String, _QuestionVm>{};
    for (final q in [...normalizedQuestions.across, ...normalizedQuestions.down]) {
      byId[q.id] = q;
    }

    final questionIdsByCell = <int, List<String>>{};
    final expectedLetterByCell = <int, String>{};
    for (final q in [...normalizedQuestions.across, ...normalizedQuestions.down]) {
      for (int i = 0; i < q.cellIndexes.length; i++) {
        final idx = q.cellIndexes[i];
        (questionIdsByCell[idx] ??= []).add(q.id);
        expectedLetterByCell.putIfAbsent(idx, () => q.answer[i]);
      }
    }

    final startNumberByCell = <int, int>{};
    for (final q in [...normalizedQuestions.across, ...normalizedQuestions.down]) {
      final startIdx = q.cellIndexes.isEmpty ? null : q.cellIndexes.first;
      if (startIdx == null) continue;
      final existing = startNumberByCell[startIdx];
      if (existing == null || q.number < existing) {
        startNumberByCell[startIdx] = q.number;
      }
    }

    final cells = List<ValueNotifier<_CellVm>>.generate(gridSize * gridSize, (idx) {
      final isBlock = !questionIdsByCell.containsKey(idx);
      return ValueNotifier(
        _CellVm(
          isBlock: isBlock,
          value: '',
          isHighlighted: false,
          isCursor: false,
          number: startNumberByCell[idx],
          mark: _WordMark.neutral,
        ),
      );
    });

    final controller = _CrosswordController._(
      gridSize: gridSize,
      across: normalizedQuestions.across,
      down: normalizedQuestions.down,
      cells: cells,
      letterOptions: ValueNotifier(const []),
      activeClue: ValueNotifier(''),
      activeQuestionId: ValueNotifier(null),
      questionsById: byId,
      questionIdsByCell: questionIdsByCell,
      expectedLetterByCell: expectedLetterByCell,
      userInput: <int, String>{},
      wordMarks: <String, _WordMark>{},
      keyboardBaseByQuestionId: <String, List<String>>{},
      random: Random(DateTime.now().millisecondsSinceEpoch),
    );

    controller._autoSelectDefaultQuestion();
    return controller;
  }

  void dispose() {
    for (final c in cells) {
      c.dispose();
    }
    letterOptions.dispose();
    activeClue.dispose();
    activeQuestionId.dispose();
  }

  Future<void> dispatch(FutureOr<void> Function() action) {
    _dispatchQueue = _dispatchQueue.then((_) async {
      await action();
    });
    return _dispatchQueue;
  }

  int get totalFillableCells => _expectedLetterByCell.length;

  int get correctFillableCells {
    int count = 0;
    _expectedLetterByCell.forEach((idx, expected) {
      final actual = _userInput[idx];
      if (actual != null && actual.toUpperCase() == expected.toUpperCase()) {
        count++;
      }
    });
    return count;
  }

  bool get isCompleted => totalFillableCells > 0 && correctFillableCells == totalFillableCells;

  void handleCellTap(int row, int col) {
    dispatch(() async {
      final idx = _toIndex(row, col);
      final ids = _questionIdsByCell[idx];
      if (ids == null || ids.isEmpty) return;

      final current = _cursorQuestionId != null ? _questionsById[_cursorQuestionId!] : null;
      final acrossCandidate = ids.map((id) => _questionsById[id]).whereType<_QuestionVm>().where((q) => q.direction == _Direction.across).toList();
      final downCandidate = ids.map((id) => _questionsById[id]).whereType<_QuestionVm>().where((q) => q.direction == _Direction.down).toList();

      _QuestionVm? target;
      if (current != null && ids.contains(current.id)) {
        target = current;
      } else if (acrossCandidate.isNotEmpty) {
        target = acrossCandidate.first;
      } else if (downCandidate.isNotEmpty) {
        target = downCandidate.first;
      }

      if (target == null) return;
      _selectQuestion(target.id);
      _setCursorToCellInActiveWord(idx);
    });
  }

  void selectQuestionById(String id) {
    dispatch(() async {
      _selectQuestion(id);
    });
  }

  void inputLetter(String letter) {
    dispatch(() async {
      final q = _activeQuestion;
      if (q == null) return;
      if (letterOptions.value.isEmpty) return;

      final cursorIdx = _ensureCursor();
      if (cursorIdx == null) return;

      if (_isActiveWordFull(q) && (_userInput[cursorIdx]?.isNotEmpty ?? false)) {
        return;
      }

      final normalized = _normalizeLetter(letter);
      if (normalized == null) return;

      _setCellValue(cursorIdx, normalized);
      _markWordIncomplete(q.id);
      _advanceCursor(q);

      if (_isActiveWordFull(q)) {
        _validateActiveWord(q);
        if (_wordMarks[q.id] == _WordMark.correct) {
          _selectNextQuestion();
        }
      }
    });
  }

  void backspace() {
    dispatch(() async {
      final q = _activeQuestion;
      if (q == null) return;

      final cursorIdx = _ensureCursor();
      if (cursorIdx == null) return;

      if ((_userInput[cursorIdx]?.isNotEmpty ?? false)) {
        _clearCell(cursorIdx);
        _markWordIncomplete(q.id);
        return;
      }

      final pos = q.cellIndexes.indexOf(cursorIdx);
      if (pos <= 0) return;

      final prevIdx = q.cellIndexes[pos - 1];
      _setCursor(prevIdx, q.id);
      _clearCell(prevIdx);
      _markWordIncomplete(q.id);
    });
  }

  void reset() {
    dispatch(() async {
      for (final idx in _expectedLetterByCell.keys) {
        _clearCell(idx);
      }
      _wordMarks.clear();
      _recomputeAllCellMarks();
      _autoSelectDefaultQuestion();
    });
  }

  _QuestionVm? get _activeQuestion {
    final id = activeQuestionId.value;
    if (id == null) return null;
    return _questionsById[id];
  }

  void _autoSelectDefaultQuestion() {
    final acrossFirst = across.isNotEmpty ? across.first : null;
    final downFirst = down.isNotEmpty ? down.first : null;
    final selected = acrossFirst ?? downFirst;
    if (selected == null) return;
    _selectQuestion(selected.id);
    _setCursorToFirstEmptyInActiveWord(selected);
  }

  void _setLetterOptionsForQuestion(_QuestionVm q) {
    final base = _keyboardBaseByQuestionId.putIfAbsent(q.id, () {
      final letters = <String>[];
      final upper = q.answer.toUpperCase();
      for (int i = 0; i < upper.length; i++) {
        final ch = upper[i];
        if (!RegExp(r'^[A-Z]$').hasMatch(ch)) continue;
        letters.add(ch);
      }
      if (letters.isEmpty) {
        return ['A', 'E', 'I', 'O', 'U'];
      }
      return letters;
    });

    final shuffled = base.toList();
    _fisherYatesShuffle(shuffled, _random);
    letterOptions.value = shuffled;
  }

  static void _fisherYatesShuffle(List<String> list, Random random) {
    for (int i = list.length - 1; i > 0; i--) {
      final j = random.nextInt(i + 1);
      final tmp = list[i];
      list[i] = list[j];
      list[j] = tmp;
    }
  }

  void _selectQuestion(String id) {
    final q = _questionsById[id];
    if (q == null) return;

    final previous = _activeQuestion;
    if (previous != null) {
      for (final idx in previous.cellIndexes) {
        final current = cells[idx].value;
        if (current.isHighlighted) {
          cells[idx].value = current.copyWith(isHighlighted: false);
        }
      }
    }

    activeQuestionId.value = q.id;
    activeClue.value = '${q.direction == _Direction.across ? "Across" : "Down"} ${q.number}: ${q.clue}';
    _setLetterOptionsForQuestion(q);

    for (final idx in q.cellIndexes) {
      final current = cells[idx].value;
      if (!current.isHighlighted) {
        cells[idx].value = current.copyWith(isHighlighted: true);
      }
    }

    if (_cursorQuestionId != q.id) {
      _cursorQuestionId = q.id;
      _setCursorToFirstEmptyInActiveWord(q);
    }
  }

  void _selectNextQuestion() {
    final current = _activeQuestion;
    if (current == null) return;

    final all = [...across, ...down];
    if (all.isEmpty) return;

    final currentIndex = all.indexWhere((q) => q.id == current.id);
    for (int offset = 1; offset <= all.length; offset++) {
      final next = all[(currentIndex + offset) % all.length];
      if (_wordMarks[next.id] != _WordMark.correct) {
        _selectQuestion(next.id);
        _setCursorToFirstEmptyInActiveWord(next);
        return;
      }
    }
  }

  void _setCursorToFirstEmptyInActiveWord(_QuestionVm q) {
    final firstEmpty = q.cellIndexes.firstWhere(
      (idx) => (_userInput[idx]?.isEmpty ?? true),
      orElse: () => q.cellIndexes.isNotEmpty ? q.cellIndexes.first : -1,
    );
    if (firstEmpty < 0) return;
    _setCursor(firstEmpty, q.id);
  }

  void _setCursorToCellInActiveWord(int idx) {
    final q = _activeQuestion;
    if (q == null) return;
    if (!q.cellIndexes.contains(idx)) return;
    _setCursor(idx, q.id);
  }

  int? _ensureCursor() {
    final q = _activeQuestion;
    if (q == null) return null;

    final cursorIdx = _cursorCellIndex;
    if (cursorIdx != null && q.cellIndexes.contains(cursorIdx)) {
      return cursorIdx;
    }

    _setCursorToFirstEmptyInActiveWord(q);
    return _cursorCellIndex;
  }

  void _advanceCursor(_QuestionVm q) {
    final cursorIdx = _cursorCellIndex;
    if (cursorIdx == null) return;
    final pos = q.cellIndexes.indexOf(cursorIdx);
    if (pos < 0) return;
    if (pos >= q.cellIndexes.length - 1) return;
    _setCursor(q.cellIndexes[pos + 1], q.id);
  }

  void _setCursor(int idx, String questionId) {
    final previousIdx = _cursorCellIndex;
    if (previousIdx != null && previousIdx != idx) {
      final prevVm = cells[previousIdx].value;
      if (prevVm.isCursor) {
        cells[previousIdx].value = prevVm.copyWith(isCursor: false);
      }
    }
    _cursorCellIndex = idx;
    _cursorQuestionId = questionId;

    final vm = cells[idx].value;
    if (!vm.isCursor) {
      cells[idx].value = vm.copyWith(isCursor: true);
    }
  }

  void _setCellValue(int idx, String value) {
    _userInput[idx] = value;
    final vm = cells[idx].value;
    if (vm.value != value) {
      cells[idx].value = vm.copyWith(value: value);
    }
  }

  void _clearCell(int idx) {
    _userInput.remove(idx);
    final vm = cells[idx].value;
    if (vm.value.isNotEmpty) {
      cells[idx].value = vm.copyWith(value: '');
    }
  }

  bool _isActiveWordFull(_QuestionVm q) {
    for (final idx in q.cellIndexes) {
      final v = _userInput[idx];
      if (v == null || v.isEmpty) return false;
    }
    return true;
  }

  void _validateActiveWord(_QuestionVm q) {
    if (q.answer.isEmpty || q.cellIndexes.isEmpty) return;

    final buffer = StringBuffer();
    for (final idx in q.cellIndexes) {
      buffer.write(_userInput[idx] ?? '');
    }
    final userWord = buffer.toString().toUpperCase();
    final expected = q.answer.toUpperCase();

    // Critical: validation is per word (not per character).
    final mark = userWord == expected ? _WordMark.correct : _WordMark.wrong;
    _wordMarks[q.id] = mark;
    _recomputeAllCellMarks();
  }

  void _markWordIncomplete(String questionId) {
    if (_wordMarks[questionId] != null) {
      _wordMarks.remove(questionId);
      _recomputeAllCellMarks();
    }
  }

  void _recomputeAllCellMarks() {
    // Critical: overlaps derive their color from word-level marks.
    for (final entry in _questionIdsByCell.entries) {
      final idx = entry.key;
      final ids = entry.value;
      _WordMark mark = _WordMark.neutral;
      for (final id in ids) {
        final m = _wordMarks[id];
        if (m == _WordMark.wrong) {
          mark = _WordMark.wrong;
          break;
        }
        if (m == _WordMark.correct) {
          mark = _WordMark.correct;
        }
      }
      final vm = cells[idx].value;
      if (vm.mark != mark) {
        cells[idx].value = vm.copyWith(mark: mark);
      }
    }
  }

  static int _toIndexStatic(int row, int col, {required int gridSize}) => row * gridSize + col;

  int _toIndex(int row, int col) => row * gridSize + col;

  static String? _normalizeLetter(String raw) {
    final upper = raw.trim().toUpperCase();
    if (upper.isEmpty) return null;
    final ch = upper[0];
    if (!RegExp(r'^[A-Z]$').hasMatch(ch)) return null;
    return ch;
  }

  static ({List<_QuestionVm> across, List<_QuestionVm> down}) _normalizeQuestions(
    List<CrosswordQuestion> questions,
    int gridSize,
  ) {
    final across = <_QuestionVm>[];
    final down = <_QuestionVm>[];

    for (final q in questions) {
      final clue = q.clue.trim();
      final answer = q.answer.trim().toUpperCase();
      if (answer.isEmpty) continue;

      final direction = q.isAcross ? _Direction.across : _Direction.down;
      final cellIndexes = <int>[];
      bool outOfBounds = false;

      for (int i = 0; i < answer.length; i++) {
        final row = direction == _Direction.across ? q.row : q.row + i;
        final col = direction == _Direction.across ? q.col + i : q.col;
        if (row < 0 || col < 0 || row >= gridSize || col >= gridSize) {
          outOfBounds = true;
          break;
        }
        cellIndexes.add(_toIndexStatic(row, col, gridSize: gridSize));
      }

      if (outOfBounds || cellIndexes.isEmpty) continue;

      final id = '${direction.name}-${q.number}-${q.row}-${q.col}';
      final vm = _QuestionVm(
        id: id,
        number: q.number,
        clue: clue.isEmpty ? '(No clue)' : clue,
        answer: answer,
        direction: direction,
        startRow: q.row,
        startCol: q.col,
        cellIndexes: cellIndexes,
      );

      if (direction == _Direction.across) {
        across.add(vm);
      } else {
        down.add(vm);
      }
    }

    across.sort((a, b) => a.number.compareTo(b.number));
    down.sort((a, b) => a.number.compareTo(b.number));
    return (across: across, down: down);
  }
}

class CrosswordView extends StatefulWidget {
  final CrosswordPresenter presenter;

  const CrosswordView({super.key, required this.presenter});

  @override
  State<CrosswordView> createState() => _CrosswordViewState();
}

class _CrosswordViewState extends State<CrosswordView> {
  late final _CrosswordController _controller;

  int remainingSeconds = 600;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = _CrosswordController.fromLevel(widget.presenter.model, gridSize: 15);
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (remainingSeconds <= 0) {
        timer.cancel();
        _showTimeUpDialog();
        return;
      }
      setState(() {
        remainingSeconds--;
      });
    });
  }

  void _showCompletionDialog() {
    final scoreManager = ScoreManager();
    final score = 100 + remainingSeconds;
    scoreManager.saveScore(widget.presenter.model.id, score);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Congratulations!"),
          content: Text("All answers are correct 🎉\nYour score: $score"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop(true);
              },
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
  }

  void _showTimeUpDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Time's Up ⏰"),
          content: const Text("The game time has run out."),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  remainingSeconds = 600;
                });
                _controller.reset();
                _startTimer();
              },
              child: const Text("Restart"),
            ),
          ],
        );
      },
    );
  }

  Color _cellFillColor(_CellVm vm) {
    if (vm.isBlock) return const Color(0xFF20262B);
    if (vm.mark == _WordMark.correct) return Colors.green;
    if (vm.mark == _WordMark.wrong) return Colors.red;
    if (vm.isCursor) return const Color(0xFFFFE082);
    if (vm.isHighlighted) return const Color(0xFFFFC1E3);
    return Colors.white;
  }

  Color _cellTextColor(_CellVm vm) {
    if (vm.mark == _WordMark.correct || vm.mark == _WordMark.wrong) return Colors.white;
    return Colors.black;
  }

  @override
  Widget build(BuildContext context) {
    final progress = _controller.totalFillableCells == 0
        ? 0.0
        : _controller.correctFillableCells / _controller.totalFillableCells;

    return Scaffold(
      resizeToAvoidBottomInset: false,
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
            child: Image.asset(
              'assets/background.jpg',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(
              color: const Color(0xFF173A8C).withAlpha(135),
            ),
          ),
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Row(
                  children: [
                    GameProgressStar(progress: progress),
                    const Spacer(),
                    GameTimerDisplay(remainingSeconds: remainingSeconds),
                    const Spacer(),
                    GameActionButton(
                      icon: Icons.auto_fix_high,
                      badge: "1",
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Hint feature coming soon!")),
                        );
                      },
                    ),
                    const SizedBox(width: 12),
                    GameActionButton(
                      icon: Icons.search,
                      badge: "1",
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Search feature coming soon!")),
                        );
                      },
                    ),
                    const SizedBox(width: 12),
                    GameActionButton(
                      icon: Icons.refresh,
                      onTap: () {
                        setState(() {
                          remainingSeconds = 600;
                        });
                        _controller.reset();
                        _startTimer();
                      },
                    ),
                  ],
                ),
              ),
              _buildClueHeader(),
              const SizedBox(height: 10),
              Expanded(
                flex: 3,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final maxBoard = min(constraints.maxWidth, constraints.maxHeight);
                    final rawCell = maxBoard / _controller.gridSize;
                    final cellSize = rawCell.clamp(22.0, 44.0);
                    final boardSize = cellSize * _controller.gridSize;

                    return Center(
                      child: _CellMetrics(
                        cellSize: cellSize,
                        child: SizedBox(
                          width: boardSize,
                          height: boardSize,
                          child: GridView.builder(
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _controller.gridSize * _controller.gridSize,
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: _controller.gridSize,
                              mainAxisSpacing: 2,
                              crossAxisSpacing: 2,
                              childAspectRatio: 1,
                            ),
                            itemBuilder: (context, index) => _buildCell(index),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              _buildKeyboard(),
              Expanded(
                flex: 2,
                child: _buildQuestionsPanel(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCell(int index) {
    return ValueListenableBuilder<_CellVm>(
      valueListenable: _controller.cells[index],
      builder: (context, vm, _) {
        final fillColor = _cellFillColor(vm);
        final textColor = _cellTextColor(vm);
        final cellSize = _CellMetrics.of(context).cellSize;
        final fontSize = (_CellMetrics.of(context).cellSize * 0.58).clamp(16.0, 26.0);

        return GestureDetector(
          onTap: vm.isBlock
              ? null
              : () {
                  final row = index ~/ _controller.gridSize;
                  final col = index % _controller.gridSize;
                  _controller.handleCellTap(row, col);
                },
          child: Container(
            margin: EdgeInsets.zero,
            decoration: BoxDecoration(
              color: fillColor,
              border: Border.all(
                color: const Color(0xFF20262B),
                width: 1,
              ),
            ),
            child: Stack(
              children: [
                if (vm.number != null)
                  Positioned(
                    top: 1,
                    left: 1,
                    child: Text(
                      '${vm.number}',
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        color: textColor.withAlpha(180),
                      ),
                    ),
                  ),
                SizedBox(
                  width: cellSize,
                  height: cellSize,
                  child: Center(
                    child: Text(
                      vm.value,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.visible,
                      strutStyle: const StrutStyle(
                        height: 1.0,
                        forceStrutHeight: true,
                      ),
                      style: TextStyle(
                        fontSize: fontSize,
                        height: 1.0,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildKeyboard() {
    return ValueListenableBuilder<List<String>>(
      valueListenable: _controller.letterOptions,
      builder: (context, letters, _) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          color: Colors.white.withAlpha(230),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: letters.map((letter) {
                  return SizedBox(
                    width: 42,
                    height: 42,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        shape: const StadiumBorder(),
                        backgroundColor: const Color(0xFF1488CC),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        _controller.inputLetter(letter);
                        if (_controller.isCompleted) {
                          _showCompletionDialog();
                        }
                      },
                      child: Text(
                        letter,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 20,
                          height: 1.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0B2156),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => _controller.backspace(),
                      child: const Text("Backspace"),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildClueHeader() {
    return ValueListenableBuilder<String>(
      valueListenable: _controller.activeClue,
      builder: (context, clue, _) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(235),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            clue,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuestionsPanel() {
    return ValueListenableBuilder<String?>(
      valueListenable: _controller.activeQuestionId,
      builder: (context, activeId, _) {
        Widget buildList(String title, List<_QuestionVm> items) {
          return Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                ),
                const Divider(),
                Expanded(
                  child: ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, i) {
                      final q = items[i];
                      final selected = q.id == activeId;
                      return GestureDetector(
                        onTap: () => _controller.selectQuestionById(q.id),
                        child: Container(
                          color: selected ? Colors.blue.withAlpha(51) : Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                          child: Text(
                            '${q.number}. ${q.clue}',
                            style: TextStyle(fontWeight: selected ? FontWeight.bold : FontWeight.normal),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.all(8),
          color: Colors.white.withAlpha(230),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              buildList("ACROSS", _controller.across),
              const SizedBox(width: 16),
              buildList("DOWN", _controller.down),
            ],
          ),
        );
      },
    );
  }

}

class _CellMetrics extends InheritedWidget {
  final double cellSize;

  const _CellMetrics({
    required this.cellSize,
    required super.child,
  });

  static _CellMetrics of(BuildContext context) {
    final metrics = context.dependOnInheritedWidgetOfExactType<_CellMetrics>();
    if (metrics == null) {
      throw StateError('_CellMetrics not found');
    }
    return metrics;
  }

  @override
  bool updateShouldNotify(_CellMetrics oldWidget) => cellSize != oldWidget.cellSize;
}
