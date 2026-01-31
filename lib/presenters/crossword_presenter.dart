import '../models/crossword_model.dart';

class CrosswordPresenter {
  final LevelModel model;

  CrosswordPresenter(this.model);

  CrosswordQuestion? findQuestion(int row, int col) {
    for (var q in model.questions) {
      if (q.isAcross) {
        if (q.row == row && col >= q.col && col < q.col + q.answer.length) {
          return q;
        }
      } else {
        if (q.col == col && row >= q.row && row < q.row + q.answer.length) {
          return q;
        }
      }
    }
    return null;
  }

  bool validateLetter(CrosswordQuestion question, int row, int col, String input) {
    int index;
    if (question.isAcross) {
      index = col - question.col;
    } else {
      index = row - question.row;
    }
    return question.answer[index].toUpperCase() == input.toUpperCase();
  }

  List<CrosswordQuestion> getAcrossQuestions() {
    return model.questions.where((q) => q.isAcross).toList();
  }

  List<CrosswordQuestion> getDownQuestions() {
    return model.questions.where((q) => !q.isAcross).toList();
  }

  int totalCells() {
    int count = 0;
    for (var q in model.questions) {
      count += q.answer.length;
    }
    return count;
  }
}
