import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as path;
import 'processor.dart';
import 'aho_corasick.dart';
import 'ulp_database.dart';

void main() => runApp(const LogCleanerApp());

class LogCleanerApp extends StatelessWidget {
  const LogCleanerApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Elite Log Processor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0a0a0f),
        primaryColor: const Color(0xFF00ffff),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00ffff),
          secondary: Color(0xFFff006e),
          background: Color(0xFF0a0a0f),
        ),
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final LogProcessor _processor = LogProcessor();
  
  String _status = 'Ready';
  double _progress = 0.0;
  int _processedFiles = 0;
  int _totalFiles = 0;
  int _foundMatches = 0;
  bool _isProcessing = false;
  
  final TextEditingController _customStringController = TextEditingController();
  final Set<String> _selectedCountries = {};
  final Set<String> _selectedProviders = {};
  final Set<String> _selectedKeywords = {};
  
  bool _cleanMode = false;
  bool _ulpScanMode = false;

  @override
  void initState() {
    super.initState();
    _processor.onProgress = (current, total, matches) {
      setState(() {
        _processedFiles = current;
        _totalFiles = total;
        _foundMatches = matches;
        _progress = total > 0 ? current / total : 0.0;
      });
    };
    _processor.onStatusChange = (status) {
      setState(() => _status = status);
    };
  }

  Future<void> _selectFiles() async {
    if (_isProcessing) return;
    
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['txt', 'zip', '7z', 'log'],
    );

    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _isProcessing = true;
        _progress = 0.0;
        _processedFiles = 0;
        _totalFiles = 0;
        _foundMatches = 0;
      });

      final config = ProcessConfig(
        inputPaths: result.paths.whereType<String>().toList(),
        outputDir: '/storage/emulated/0/Download/clean-output',
        customReplaceString: _customStringController.text.isEmpty 
            ? null 
            : _customStringController.text,
        countryFilter: _selectedCountries.isEmpty ? null : _selectedCountries,
        providerFilter: _selectedProviders.isEmpty ? null : _selectedProviders,
        ulpKeywords: _selectedKeywords.isEmpty ? null : _selectedKeywords,
        cleanMode: _cleanMode,
        ulpScanMode: _ulpScanMode,
      );

      await _processor.process(config);

      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildModeSelector(),
                    const SizedBox(height: 20),
                    if (_cleanMode) _buildCleanerOptions(),
                    if (_ulpScanMode) _buildUlpOptions(),
                    const SizedBox(height: 20),
                    _buildFilterSection(),
                    const SizedBox(height: 30),
                    _buildActionButton(),
                    if (_isProcessing) ...[
                      const SizedBox(height: 30),
                      _buildProgressSection(),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1a0033),
            const Color(0xFF0a0a0f),
          ],
        ),
        border: Border(
          bottom: BorderSide(color: const Color(0xFF00ffff), width: 2),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFF00ffff), width: 2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.security, color: Color(0xFF00ffff)),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ELITE LOG PROCESSOR',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFff6b35),
                  ),
                ),
                Text(
                  _status,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF00ff87),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeSelector() {
    return Row(
      children: [
        Expanded(
          child: _buildModeCard(
            'CLEANER',
            Icons.cleaning_services,
            _cleanMode,
            () => setState(() => _cleanMode = !_cleanMode),
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: _buildModeCard(
            'ULP SCAN',
            Icons.search,
            _ulpScanMode,
            () => setState(() => _ulpScanMode = !_ulpScanMode),
          ),
        ),
      ],
    );
  }

  Widget _buildModeCard(String title, IconData icon, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF1a1a2e) : const Color(0xFF0f0f1a),
          border: Border.all(
            color: active ? const Color(0xFF00ffff) : const Color(0xFF2a2a3e),
            width: 2,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: active ? const Color(0xFF00ffff) : const Color(0xFF5a5a6e),
              size: 32,
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                color: active ? const Color(0xFF00ffff) : const Color(0xFF5a5a6e),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCleanerOptions() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF1a1a2e),
        border: Border.all(color: const Color(0xFFff006e), width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'REPLACEMENT STRING',
            style: TextStyle(
              color: Color(0xFFff006e),
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _customStringController,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: '@YourChannel',
              hintStyle: const TextStyle(color: Color(0xFF5a5a6e), fontSize: 12),
              filled: true,
              fillColor: const Color(0xFF0f0f1a),
              contentPadding: const EdgeInsets.all(12),
              border: OutlineInputBorder(
                borderSide: BorderSide(color: const Color(0xFF2a2a3e)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUlpOptions() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF1a1a2e),
        border: Border.all(color: const Color(0xFF00ff87), width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ULP KEYWORDS',
            style: TextStyle(
              color: Color(0xFF00ff87),
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: UlpDatabase.categories.keys.map((entry) {
              final selected = _selectedKeywords.contains(entry);
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (selected) {
                      _selectedKeywords.remove(entry);
                    } else {
                      _selectedKeywords.add(entry);
                    }
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: selected ? const Color(0xFF00ff87) : const Color(0xFF0f0f1a),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    entry.toUpperCase(),
                    style: TextStyle(
                      color: selected ? Colors.black : const Color(0xFF00ff87),
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'FILTERS',
          style: TextStyle(
            color: Color(0xFF00ffff),
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 12),
        _buildFilterChips(
          'Countries',
          ['US', 'UK', 'CA', 'DE', 'FR', 'TR', 'RU', 'BR'],
          _selectedCountries,
        ),
        const SizedBox(height: 10),
        _buildFilterChips(
          'Providers',
          ['gmail', 'yahoo', 'hotmail', 'outlook', 'proton'],
          _selectedProviders,
        ),
      ],
    );
  }

  Widget _buildFilterChips(String label, List<String> options, Set<String> selected) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF5a5a6e),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: options.map((option) {
            final isSelected = selected.contains(option);
            return GestureDetector(
              onTap: () {
                setState(() {
                  if (isSelected) {
                    selected.remove(option);
                  } else {
                    selected.add(option);
                  }
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF00ffff) : const Color(0xFF1a1a2e),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF00ffff) : const Color(0xFF2a2a3e),
                  ),
                ),
                child: Text(
                  option,
                  style: TextStyle(
                    color: isSelected ? Colors.black : const Color(0xFF00ffff),
                    fontSize: 11,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildActionButton() {
    return ElevatedButton(
      onPressed: _isProcessing ? null : _selectFiles,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFff6b35),
        disabledBackgroundColor: const Color(0xFF3a3a3a),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Text(
        _isProcessing ? 'PROCESSING...' : 'SELECT FILES',
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildProgressSection() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF1a1a2e),
        border: Border.all(color: const Color(0xFF00ffff)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          LinearProgressIndicator(
            value: _progress,
            backgroundColor: const Color(0xFF2a2a3e),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00ffff)),
            minHeight: 6,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStat('FILES', '$_processedFiles/$_totalFiles'),
              _buildStat('MATCHES', '$_foundMatches'),
              _buildStat('%', '${(_progress * 100).toStringAsFixed(0)}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF5a5a6e),
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF00ffff),
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _customStringController.dispose();
    _processor.dispose();
    super.dispose();
  }
}
