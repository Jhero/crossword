import 'dart:convert';

class CrosswordQuestion {
  final int number;
  final String clue;
  final String answer;
  final bool isAcross;
  final int row;
  final int col;
  final int? levelId;

  CrosswordQuestion({
    required this.number,
    required this.clue,
    required this.answer,
    required this.isAcross,
    required this.row,
    required this.col,
    this.levelId,
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

  factory CrosswordQuestion.fromApiJson(Map<String, dynamic> json) {
    final dynamic isAcrossRaw = json['isAcross'] ?? json['is_across'];
    return CrosswordQuestion(
      number: json['number'],
      clue: json['clue'],
      answer: json['answer'],
      isAcross: isAcrossRaw == true || isAcrossRaw == 1,
      row: json['row'],
      col: json['col'],
      levelId: json['level_id'],
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

  factory LevelModel.fromApiJson(Map<String, dynamic> json) {
    return LevelModel(
      id: json['id'],
      title: json['name'] ?? json['title'],
      questions: const [],
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
