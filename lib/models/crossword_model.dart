import 'dart:convert';

class CrosswordQuestion {
  final int number;
  final String clue;
  final String answer;
  final bool isAcross;
  final int row;
  final int col;

  CrosswordQuestion({
    required this.number,
    required this.clue,
    required this.answer,
    required this.isAcross,
    required this.row,
    required this.col,
  });

  factory CrosswordQuestion.fromJson(Map<String, dynamic> json) {
    return CrosswordQuestion(
      number: json['number'],
      clue: json['clue'],
      answer: json['answer'],
      isAcross: json['isAcross'],
      row: json['row'],
      col: json['col'],
    );
  }
}

class LevelModel {
  final int id;
  final String title;
  final List<CrosswordQuestion> questions;

  LevelModel({required this.id, required this.title, required this.questions});

  factory LevelModel.fromJson(Map<String, dynamic> json) {
    return LevelModel(
      id: json['id'],
      title: json['title'],
      questions: (json['questions'] as List)
          .map((q) => CrosswordQuestion.fromJson(q))
          .toList(),
    );
  }
}

class CrosswordData {
  final List<LevelModel> levels;

  CrosswordData(this.levels);

  factory CrosswordData.fromJson(String jsonStr) {
    final data = json.decode(jsonStr);
    final list = (data['levels'] as List)
        .map((l) => LevelModel.fromJson(l))
        .toList();
    return CrosswordData(list);
  }
}
