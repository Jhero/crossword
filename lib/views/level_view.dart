import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/crossword_model.dart';
import '../presenters/crossword_presenter.dart';
import '../utils/score_manager.dart';
import 'about_view.dart';
import 'crossword_view.dart';

class LevelView extends StatefulWidget {
  const LevelView({super.key});

  @override
  State<LevelView> createState() => _LevelViewState();
}

class _LevelViewState extends State<LevelView> {
  final ScoreManager _scoreManager = ScoreManager();
  Map<int, int> _scores = {};
  int _selectedIndex = 0;
  List<LevelModel> _levels = [];
  bool _isLoadingLevels = true;
  String? _levelsError;
  int? _loadingLevelId;
  Map<String, String>? _env;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    setState(() {
      _isLoadingLevels = true;
      _levelsError = null;
    });

    try {
      final env = await _loadEnv();
      if (!mounted) return;
      setState(() {
        _env = env;
      });
      await _fetchLevels();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingLevels = false;
        _levelsError = e.toString();
      });
    }
  }

  Future<Map<String, String>> _loadEnv() async {
    final raw = await rootBundle.loadString('.env');
    final env = <String, String>{};
    for (final line in raw.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      if (trimmed.startsWith('#')) continue;
      final eq = trimmed.indexOf('=');
      if (eq <= 0) continue;
      final key = trimmed.substring(0, eq).trim();
      final value = trimmed.substring(eq + 1).trim();
      if (key.isNotEmpty) {
        env[key] = value;
      }
    }
    _validateEnv(env);
    return env;
  }

  void _validateEnv(Map<String, String> env) {
    final baseUrl = env['API_BASE_URL']?.trim() ?? '';
    final apiKey = env['API_KEY']?.trim() ?? '';

    if (baseUrl.isEmpty) {
      throw StateError("API_BASE_URL is missing in .env");
    }

    final uri = Uri.tryParse(baseUrl);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw StateError("API_BASE_URL is invalid: $baseUrl");
    }

    if (apiKey.isEmpty) {
      throw StateError("API_KEY is missing in .env");
    }

    if (!RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(apiKey)) {
      throw StateError(
        "API_KEY format is invalid in .env. It should be a 64-character hex token.",
      );
    }
  }

  String _requireEnv(String key) {
    final value = _env?[key];
    if (value == null || value.trim().isEmpty) {
      throw StateError("Missing env: $key");
    }
    return value.trim();
  }

  Uri _buildUri(String path, Map<String, String> query) {
    final baseUrl = _requireEnv('API_BASE_URL').replaceAll(RegExp(r'/$'), '');
    return Uri.parse('$baseUrl$path').replace(queryParameters: query);
  }

  Map<String, String> _headers() {
    return {
      'X-API-KEY': _requireEnv('API_KEY'),
      'Accept': 'application/json',
    };
  }

  Future<List<LevelModel>> _getAllLevels() async {
    const limit = 100;
    int page = 1;
    final levels = <LevelModel>[];

    while (true) {
      final uri = _buildUri(
        '/crosswords/levels',
        {'page': '$page', 'limit': '$limit'},
      );
      final decoded = await _getJson(uri);
      final data = (decoded['data'] as List).cast<Map<String, dynamic>>();
      levels.addAll(data.map(LevelModel.fromApiJson));

      final meta = decoded['meta'];
      if (meta is Map<String, dynamic> && meta['total_pages'] != null) {
        final totalPages = meta['total_pages'] as int;
        if (page >= totalPages) break;
      } else {
        if (data.length < limit) break;
      }
      page++;
    }

    return levels;
  }

  Future<List<CrosswordQuestion>> _getQuestionsForLevel(int levelId) async {
    const limit = 200;
    int page = 1;
    final questions = <CrosswordQuestion>[];

    while (true) {
      final uri = _buildUri(
        '/crosswords/questions',
        {'page': '$page', 'limit': '$limit', 'level_id': '$levelId'},
      );
      final decoded = await _getJson(uri);
      final data = (decoded['data'] as List).cast<Map<String, dynamic>>();
      final pageQuestions = data.map(CrosswordQuestion.fromApiJson).where((q) {
        return q.levelId == null || q.levelId == levelId;
      });
      questions.addAll(pageQuestions);

      final meta = decoded['meta'];
      if (meta is Map<String, dynamic> && meta['total_pages'] != null) {
        final totalPages = meta['total_pages'] as int;
        if (page >= totalPages) break;
      } else {
        if (data.length < limit) break;
      }
      page++;
    }

    return questions;
  }

  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    final client = HttpClient();
    try {
      client.connectionTimeout = const Duration(seconds: 10);
      final req = await client.getUrl(uri);
      _headers().forEach((k, v) => req.headers.set(k, v));
      final res = await req.close().timeout(const Duration(seconds: 15));
      final body = await res.transform(utf8.decoder).join();
      if (res.statusCode < 200 || res.statusCode >= 300) {
        if (res.statusCode == 401) {
          throw StateError(
            "API unauthorized (401). Check API_KEY in .env.",
          );
        }
        throw StateError("API failed: ${res.statusCode} ${uri.path}");
      }
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        throw StateError("Invalid API response");
      }
      return decoded;
    } on SocketException catch (e) {
      throw StateError(
        "Cannot reach ${uri.host}:${uri.port} (${e.message}). "
        "Make sure the phone and server are on the same network, the backend is listening on 0.0.0.0, and Windows Firewall allows port ${uri.port}.",
      );
    } on TimeoutException {
      throw StateError(
        "Request to ${uri.host}:${uri.port} timed out. Check that the server is reachable from the device.",
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _loadScores() async {
    final scores = <int, int>{};
    for (var level in _levels) {
      scores[level.id] = await _scoreManager.getScore(level.id);
    }
    if (mounted) {
      setState(() {
        _scores = scores;
      });
    }
  }

  Future<void> _fetchLevels() async {
    setState(() {
      _isLoadingLevels = true;
      _levelsError = null;
    });

    try {
      final levels = await _getAllLevels();
      if (!mounted) return;
      setState(() {
        _levels = levels;
        _isLoadingLevels = false;
      });
      await _loadScores();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingLevels = false;
        _levelsError = e.toString();
      });
    }
  }

  void _showRateUsDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Beri Nilai Kami"),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Apakah Anda menyukai aplikasi ini?"),
              SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.star, color: Colors.amber, size: 32),
                  Icon(Icons.star, color: Colors.amber, size: 32),
                  Icon(Icons.star, color: Colors.amber, size: 32),
                  Icon(Icons.star, color: Colors.amber, size: 32),
                  Icon(Icons.star, color: Colors.amber, size: 32),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Nanti Saja"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Terima kasih atas penilaian Anda!")),
                );
              },
              child: const Text("Beri Bintang 5"),
            ),
          ],
        );
      },
    );
  }

  void _onItemTapped(int index) {
    if (index == 2) {
      _showRateUsDialog();
    } else {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  Widget _buildLevelGrid() {
    if (_isLoadingLevels) {
      return const SafeArea(
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_levelsError != null) {
      return SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _levelsError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _fetchLevels,
                  child: const Text("Coba Lagi"),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.9,
          ),
          itemCount: _levels.length,
          itemBuilder: (context, index) {
            final level = _levels[index];
            final score = _scores[level.id] ?? 0;
            final isCompleted = score > 0;
            final isLoadingThis = _loadingLevelId == level.id;

            return Card(
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              color: Colors.white.withAlpha(230),
              child: InkWell(
                onTap: () async {
                  final messenger = ScaffoldMessenger.of(this.context);
                  final navigator = Navigator.of(this.context);
                  setState(() {
                    _loadingLevelId = level.id;
                  });

                  try {
                    final questions = await _getQuestionsForLevel(level.id);
                    if (!mounted) return;
                    if (questions.isEmpty) {
                      setState(() {
                        _loadingLevelId = null;
                      });
                      messenger.showSnackBar(
                        const SnackBar(content: Text("Soal belum tersedia untuk level ini.")),
                      );
                      return;
                    }

                    final levelWithQuestions = LevelModel(
                      id: level.id,
                      title: level.title,
                      questions: questions,
                    );

                  final result = await navigator.push(
                    MaterialPageRoute(
                      builder: (_) => CrosswordView(
                        presenter: CrosswordPresenter(levelWithQuestions),
                      ),
                    ),
                  );
                  if (!mounted) return;
                  setState(() {
                    _loadingLevelId = null;
                  });
                  if (result == true) {
                    _loadScores();
                  }
                  } catch (e) {
                    if (!mounted) return;
                    setState(() {
                      _loadingLevelId = null;
                    });
                    messenger.showSnackBar(
                      SnackBar(content: Text("Gagal memuat soal: $e")),
                    );
                  }
                },
                borderRadius: BorderRadius.circular(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isCompleted ? Colors.green.shade100 : Colors.blue.shade100,
                      ),
                      child: isLoadingThis
                          ? SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  isCompleted ? Colors.green.shade900 : Colors.blue.shade900,
                                ),
                              ),
                            )
                          : Text(
                              "${level.id}",
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: isCompleted ? Colors.green.shade900 : Colors.blue.shade900,
                              ),
                            ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text(
                        level.title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (score > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          "Skor: $score",
                          style: TextStyle(
                            color: Colors.amber.shade900,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          _selectedIndex == 0 ? "Pilih Level" : "Tentang Kami",
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        automaticallyImplyLeading: false, // Remove back button if any
      ),
      body: Stack(
        children: [
          // Background Image
          Positioned.fill(
            child: Image.asset(
              'assets/background.jpg',
              fit: BoxFit.cover,
            ),
          ),
          // Content
          _selectedIndex == 0 ? _buildLevelGrid() : const SafeArea(child: AboutView()),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Beranda',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.info),
            label: 'Tentang',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.star),
            label: 'Beri Nilai',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: const Color(0xFF2B32B2),
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
        backgroundColor: Colors.white,
        elevation: 10,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
