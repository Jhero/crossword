import 'package:shared_preferences/shared_preferences.dart';

class ScoreManager {
  static const String _scoreKeyPrefix = 'level_score_';

  Future<void> saveScore(int levelId, int score) async {
    final prefs = await SharedPreferences.getInstance();
    // Only save if the new score is higher than the existing one
    int currentScore = await getScore(levelId);
    if (score > currentScore) {
      await prefs.setInt('$_scoreKeyPrefix$levelId', score);
    }
  }

  Future<int> getScore(int levelId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('$_scoreKeyPrefix$levelId') ?? 0;
  }
  
  Future<void> clearScores() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    for(String key in keys) {
      if(key.startsWith(_scoreKeyPrefix)) {
        await prefs.remove(key);
      }
    }
  }
}
