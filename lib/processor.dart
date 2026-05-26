import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as path;
import 'aho_corasick.dart';
import 'ulp_database.dart';

class ProcessConfig {
  final List<String> inputPaths;
  final String outputDir;
  final String? customReplaceString;
  final Set<String>? countryFilter;
  final Set<String>? categoryFilter;
  final Set<String>? providerFilter;
  final Set<String>? ulpKeywords;
  final bool cleanMode;
  final bool ulpScanMode;

  ProcessConfig({
    required this.inputPaths,
    required this.outputDir,
    this.customReplaceString,
    this.countryFilter,
    this.categoryFilter,
    this.providerFilter,
    this.ulpKeywords,
    this.cleanMode = false,
    this.ulpScanMode = false,
  });
}

class LogProcessor {
  Function(int current, int total, int matches)? onProgress;
  Function(String status)? onStatusChange;
  
  final Set<String> _seenEntries = {};
  int _totalMatches = 0;

  Future<void> process(ProcessConfig config) async {
    _seenEntries.clear();
    _totalMatches = 0;
    
    final outputDir = Directory(config.outputDir);
    if (!await outputDir.exists()) {
      await outputDir.create(recursive: true);
    }

    onStatusChange?.call('Scanning...');
    
    final files = await _expandPaths(config.inputPaths);
    final totalFiles = files.length;

    for (int i = 0; i < files.length; i++) {
      final file = files[i];
      onProgress?.call(i + 1, totalFiles, _totalMatches);
      onStatusChange?.call('Processing: ${path.basename(file)}');

      if (file.endsWith('.zip') || file.endsWith('.7z')) {
        await _processArchive(file, config, outputDir);
      } else {
        await _processFile(file, config, outputDir);
      }
    }

    onStatusChange?.call('Done! Matches: $_totalMatches');
  }

  Future<List<String>> _expandPaths(List<String> paths) async {
    final result = <String>[];
    for (final p in paths) {
      final file = File(p);
      if (await file.exists()) {
        result.add(p);
      }
    }
    return result;
  }

  Future<void> _processArchive(String archivePath, ProcessConfig config, Directory outputDir) async {
    try {
      final bytes = await File(archivePath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      for (final file in archive.files) {
        if (file.isFile && (file.name.endsWith('.txt') || file.name.endsWith('.log'))) {
          final content = String.fromCharCodes(file.content as List<int>);
          final lines = content.split('\n');
          
          final processed = _processLines(lines, config);
          _totalMatches += processed.length;

          if (processed.isNotEmpty) {
            final outputFile = File(path.join(
              outputDir.path,
              '${path.basenameWithoutExtension(file.name)}_clean.txt',
            ));
            await outputFile.writeAsString(processed.join('\n'), mode: FileMode.append);
          }
        }
      }
    } catch (e) {
      onStatusChange?.call('Error: ${path.basename(archivePath)}');
    }
  }

  Future<void> _processFile(String filePath, ProcessConfig config, Directory outputDir) async {
    final file = File(filePath);
    final lines = <String>[];
    
    try {
      await for (final line in file.openRead().transform(utf8.decoder).transform(const LineSplitter())) {
        lines.add(line);
        if (lines.length >= 10000) {
          final processed = _processLines(lines, config);
          _totalMatches += processed.length;
          
          if (processed.isNotEmpty) {
            final outputFile = File(path.join(
              outputDir.path,
              '${path.basenameWithoutExtension(filePath)}_clean.txt',
            ));
            await outputFile.writeAsString(processed.join('\n'), mode: FileMode.append);
          }
          lines.clear();
        }
      }

      if (lines.isNotEmpty) {
        final processed = _processLines(lines, config);
        _totalMatches += processed.length;

        if (processed.isNotEmpty) {
          final outputFile = File(path.join(
            outputDir.path,
            '${path.basenameWithoutExtension(filePath)}_clean.txt',
          ));
          await outputFile.writeAsString(processed.join('\n'), mode: FileMode.append);
        }
      }
    } catch (e) {
      onStatusChange?.call('Error: ${path.basename(filePath)}');
    }
  }

  List<String> _processLines(List<String> lines, ProcessConfig config) {
    final result = <String>[];
    final ahoCorasick = AhoCorasick();
    
    if (config.cleanMode) {
      ahoCorasick.addPatterns([
        r't\.me/',
        r'https://t\.me/',
        r'@[a-zA-Z0-9_]{5,}',
        r'discord\.gg/',
        r'bit\.ly/',
      ]);
      ahoCorasick.build();
    }

    for (var line in lines) {
      if (line.trim().isEmpty) continue;
      if (_seenEntries.contains(line)) continue;
      
      bool shouldInclude = true;

      if (config.countryFilter != null && config.countryFilter!.isNotEmpty) {
        final hasCountry = config.countryFilter!.any((c) => line.toUpperCase().contains(c));
        if (!hasCountry) shouldInclude = false;
      }

      if (config.providerFilter != null && config.providerFilter!.isNotEmpty) {
        final hasProvider = config.providerFilter!.any((p) => line.toLowerCase().contains(p));
        if (!hasProvider) shouldInclude = false;
      }

      if (config.cleanMode && ahoCorasick.search(line).isNotEmpty) {
        if (config.customReplaceString != null) {
          line = ahoCorasick.replaceAll(line, config.customReplaceString!);
        } else {
          shouldInclude = false;
        }
      }

      if (config.ulpScanMode && config.ulpKeywords != null && config.ulpKeywords!.isNotEmpty) {
        final hasKeyword = config.ulpKeywords!.any((kw) => 
          UlpDatabase.categories[kw]?.any((pattern) => 
            line.toLowerCase().contains(pattern.toLowerCase())
          ) ?? false
        );
        if (!hasKeyword) shouldInclude = false;
      }

      if (shouldInclude) {
        _seenEntries.add(line);
        result.add(line);
      }
    }

    return result;
  }

  void dispose() {
    _seenEntries.clear();
  }
}
