import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── 棋盘尺寸 ─────────────────────────────────────
/// 棋盘列数
const int boardCols = 9;

/// 棋盘行数
const int boardRows = 10;

/// 棋盘格子大小（像素，会被屏幕尺寸缩放）
const double cellSize = 48.0;

/// 棋盘内边距
const double boardPadding = 24.0;

// ─── 棋盘尺寸计算 ─────────────────────────────────
/// 棋盘总宽
double boardWidth(double cell) => cell * (boardCols - 1);

/// 棋盘总高
double boardHeight(double cell) => cell * (boardRows - 1);

/// 棋盘含内边距的总尺寸
double boardTotalWidth(double cell, double pad) =>
    boardWidth(cell) + pad * 2;
double boardTotalHeight(double cell, double pad) =>
    boardHeight(cell) + pad * 2;

// ─── 颜色 ─────────────────────────────────────────
abstract class AppColors {
  // 棋盘
  static const Color boardBg = Color(0xFFDEB887); // 木色
  static const Color boardLine = Color(0xFF5D3A1A); // 深棕
  static const Color boardRiver = Color(0xFFF5F0E8); // 浅米

  // 棋子
  static const Color pieceRed = Color(0xFFCC0000);
  static const Color pieceBlack = Color(0xFF1A1A1A);
  static const Color pieceRedSelected = Color(0xFFFF4444);
  static const Color pieceBlackSelected = Color(0xFF555555);
  static const Color pieceBody = Color(0xFFF5E6C8); // 木质色
  static const Color pieceBodyHighlight = Color(0xFFFFF8E0);
  static const Color pieceBorder = Color(0xFF5D3A1A);
  static const Color pieceShadow = Color(0x40000000);

  // 选中/提示
  static const Color selectedHighlight = Color(0x66FFD700);
  static const Color validMoveHint = Color(0x664CAF50);
  static const Color lastMoveHighlight = Color(0x3366BBFF);
}

// ─── 棋子文字 ─────────────────────────────────────
/// 棋子字体大小（相对格子尺寸的比例）
const double pieceFontScale = 0.48;

// ─── 动画 ─────────────────────────────────────────
/// 走棋动画时长
const Duration moveAnimDuration = Duration(milliseconds: 300);

/// 棋子抬起高度（相对格子尺寸的比例）
const double pieceLiftScale = 0.12;

/// 棋子选中时阴影偏移
const double pieceSelectedShadowOffset = 4.0;

/// 棋子选中时阴影大小倍数
const double pieceSelectedShadowScale = 1.3;

// ─── 网络对战服务器配置 ──────────────────────────
/// 服务器地址（可在设置中修改，持久化保存）
class ServerConfig {
  static String host = '212.129.243.158';
  static int port = 8080;

  static const String _keyHost = 'server_host';
  static const String _keyPort = 'server_port';

  /// 从 SharedPreferences 加载已保存的服务器地址
  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      host = prefs.getString(_keyHost) ?? host;
      port = prefs.getInt(_keyPort) ?? port;
    } catch (_) {}
  }

  /// 保存服务器地址到本地存储
  static Future<void> save(String newHost, int newPort) async {
    host = newHost;
    port = newPort;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyHost, newHost);
      await prefs.setInt(_keyPort, newPort);
    } catch (_) {}
  }
}

// ─── 音效路径 ────────────────────────────────────
abstract class AudioPaths {
  static const String move = 'assets/audio/move.mp3';
  static const String capture = 'assets/audio/capture.mp3';
  static const String check = 'assets/audio/check.mp3';
  static const String victory = 'assets/audio/victory.mp3';
}
