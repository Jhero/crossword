import 'package:flutter/material.dart';
import '../models/crossword_model.dart';
import '../presenters/crossword_presenter.dart';
import '../utils/score_manager.dart';
import 'crossword_view.dart';
import 'about_view.dart';

class LevelView extends StatefulWidget {
  final CrosswordData data;

  const LevelView({super.key, required this.data});

  @override
  State<LevelView> createState() => _LevelViewState();
}

class _LevelViewState extends State<LevelView> {
  final ScoreManager _scoreManager = ScoreManager();
  Map<int, int> _scores = {};
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadScores();
  }

  Future<void> _loadScores() async {
    final scores = <int, int>{};
    for (var level in widget.data.levels) {
      scores[level.id] = await _scoreManager.getScore(level.id);
    }
    if (mounted) {
      setState(() {
        _scores = scores;
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
          itemCount: widget.data.levels.length,
          itemBuilder: (context, index) {
            final level = widget.data.levels[index];
            final score = _scores[level.id] ?? 0;
            final isCompleted = score > 0;

            return Card(
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              color: Colors.white.withOpacity(0.9),
              child: InkWell(
                onTap: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CrosswordView(
                        presenter: CrosswordPresenter(level),
                      ),
                    ),
                  );
                  if (result == true) {
                    _loadScores();
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
                      child: Text(
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
