// ignore_for_file: deprecated_member_use
import 'dart:io';
import 'dart:ui' as ui;
import 'package:dio/dio.dart';
import 'package:time_verse/core/network/network.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:time_verse/features/auth/auth_service/auth_service.dart';

class SavedQouteController extends ChangeNotifier {
  final List<Map<String, dynamic>> savedQuotes = [];
  final Set<int> selectedQuotes = {};
  final Map<int, GlobalKey> _cardKeys = {};

  GlobalKey getCardKey(int id) {
    if (!_cardKeys.containsKey(id)) {
      _cardKeys[id] = GlobalKey();
    }
    return _cardKeys[id]!;
  }

  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  void updateSearchQuery(String query) {
    _searchQuery = query.toLowerCase();
    selectedQuotes.clear(); // Reset selection when filtering changes
    notifyListeners();
  }

  List<Map<String, dynamic>> get filteredQuotes {
    if (_searchQuery.isEmpty) return savedQuotes;
    return savedQuotes.where((quote) {
      final description = (quote['description'] ?? '').toString().toLowerCase();
      final author = (quote['author'] ?? '').toString().toLowerCase();
      return description.contains(_searchQuery) || author.contains(_searchQuery);
    }).toList();
  }

  void toggleQuoteSelection(int index) {
    if (selectedQuotes.contains(index)) {
      selectedQuotes.remove(index);
    } else {
      selectedQuotes.add(index);
    }
    notifyListeners();
  }

  void selectAllQuotes() {
    selectedQuotes.clear();
    final list = _searchQuery.isEmpty ? savedQuotes : filteredQuotes;
    for (int i = 0; i < list.length; i++) {
      selectedQuotes.add(i);
    }
    notifyListeners();
  }

  void clearSelection() {
    selectedQuotes.clear();
    notifyListeners();
  }

  void shareSelectedQuotes(BuildContext context) {
    if (selectedQuotes.isEmpty) return;
    final list = _searchQuery.isEmpty ? savedQuotes : filteredQuotes;
    final quotesToShare = selectedQuotes
        .where((i) => i >= 0 && i < list.length)
        .map((i) => list[i]['description'])
        .where((q) => q != null && q.toString().trim().isNotEmpty)
        .join('\n\n');
    if (quotesToShare.trim().isEmpty) return;
    Share.share(quotesToShare);
  }

  Future<void> fetchSavedQuotes() async {
    try {
      final authService = AuthService();
      final token = await authService.getToken();
      final dio = createDio();
      final baseUrl = dotenv.env['BASE_URL'] ?? '';
      final url = '${baseUrl}api/v1/event/my-quotes/';

      final response = await dio.get(
        url,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        savedQuotes.clear();

        for (var item in data) {
          savedQuotes.add({
            'id': item['id'] as int? ?? 0,
            'time': item['created_at']?.toString() ?? '',
            'description': item['description']?.toString() ?? '',
            'author': item['author']?.toString() ?? '',
          });
        }
        notifyListeners();
      } else {
        debugPrint('❌ Failed to fetch saved quotes: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('⚠️ Error fetching saved quotes: $e');
    }
  }

  Future<bool> toggleFavorite(int eventId) async {
    try {
      final authService = AuthService();
      final token = await authService.getToken();
      final dio = createDio();
      final baseUrl = dotenv.env['BASE_URL'] ?? '';
      final url = '${baseUrl}api/v1/event/$eventId/favorite/';

      final response = await dio.post(
        url,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('⭐ Favorite toggled successfully: ${response.data}');
        return true;
      } else {
        debugPrint('❌ Failed with status: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('⚠️ Error toggling favorite: $e');
      return false;
    }
  }

  Future<File?> _captureCardAsImage(GlobalKey boundaryKey) async {
    try {
      final RenderRepaintBoundary? boundary = boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;

      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/quote_${DateTime.now().millisecondsSinceEpoch}.png').create();
      await file.writeAsBytes(pngBytes);
      return file;
    } catch (e) {
      debugPrint('⚠️ Error capturing card image: $e');
      return null;
    }
  }

  Future<bool> saveQuoteToGallery(GlobalKey boundaryKey) async {
    try {
      bool hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        hasAccess = await Gal.requestAccess();
        if (!hasAccess) return false;
      }

      final file = await _captureCardAsImage(boundaryKey);
      if (file == null) return false;

      final bytes = await file.readAsBytes();
      await Gal.putImageBytes(bytes, album: 'MyQuotes');
      return true;
    } catch (e) {
      debugPrint('⚠️ Error saving to gallery: $e');
      return false;
    }
  }

  Future<void> shareQuotesAsImage(dynamic quoteText, {GlobalKey? cardKey}) async {
    if (cardKey != null) {
      final file = await _captureCardAsImage(cardKey);
      if (file != null) {
        await Share.shareXFiles([XFile(file.path)], text: quoteText?.toString() ?? '');
        return;
      }
    }
    if (quoteText != null && quoteText.toString().trim().isNotEmpty) {
      Share.share(quoteText.toString());
    }
  }

  Future<void> shareAllQuotesAsImages(List<GlobalKey> cardKeys) async {
    final list = _searchQuery.isEmpty ? savedQuotes : filteredQuotes;
    final text = list
        .map((q) => '"${q['description']}" - ${q['author']}')
        .where((s) => s.trim().isNotEmpty)
        .join('\n\n');
    if (text.isNotEmpty) {
      Share.share(text);
    }
  }

  Future<void> shareSingleQuoteImage(int index, GlobalKey boundaryKey) async {
    final list = _searchQuery.isEmpty ? savedQuotes : filteredQuotes;
    if (index < 0 || index >= list.length) return;

    final quote = list[index];
    final file = await _captureCardAsImage(boundaryKey);
    if (file != null) {
      await Share.shareXFiles(
        [XFile(file.path)],
        text: '✨ "${quote['description']}" - ${quote['author']}',
      );
    }
  }

  Future<void> saveSingleQuoteToGallery(int index, GlobalKey boundaryKey) async {
    await saveQuoteToGallery(boundaryKey);
  }
}
