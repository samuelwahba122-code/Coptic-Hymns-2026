import 'dart:convert';
import 'package:flutter/services.dart';
import 'hymn_models.dart';

class HymnLoader {
  static Future<HymnData> load(String assetPath) async {
    final raw = await rootBundle.loadString(assetPath);
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return HymnData.fromJson(json);
  }
}