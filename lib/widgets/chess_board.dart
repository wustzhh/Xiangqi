import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../engine/board.dart';
import '../engine/move.dart';
import '../engine/piece.dart';
import '../engine/rules.dart';
import '../models/analysis_data.dart';
import '../utils/constants.dart';

/// 动画中的棋子信息
class AnimationPiece {
  final Piece piece;
  final Position from;
  final Position to;
  final double progress;
  const AnimationPiece({
    required this.piece,
    required this.from,
    required this.to,
    required this.progress,
  });
}

/// 棋盘组件
class ChessBoard extends StatefulWidget {
  final Board board;
  final Position? selectedPos;
  final List<Position> validMoves;
  final Move? lastMove;
  final AnimationPiece? animPiece;
  final ValueChanged<Position> onCellTap;
  final void Function(Position?)? onCellHover;
  final AnalysisMode analysisMode;
  final AnalysisData? analysisData;
  final Position? analysisSelectedPos;
  final Side playerSide;

  const ChessBoard({
    super.key,
    required this.board,
    this.selectedPos,
    this.validMoves = const [],
    this.lastMove,
    this.animPiece,
    required this.onCellTap,
    this.onCellHover,
    this.analysisMode = AnalysisMode.none,
    this.analysisData,
    this.analysisSelectedPos,
    this.playerSide = Side.red,
  });

  @override
  State<ChessBoard> createState() => _ChessBoardState();
}

class _ChessBoardState extends State<ChessBoard> {
  ui.Image? _bgImage;
  double _cellSize = 40;
  final GlobalKey _paintKey = GlobalKey();
  bool _bgLoadingAttempted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadBgImage();
  }

  Future<void> _loadBgImage() async {
    if (_bgLoadingAttempted) return;
    _bgLoadingAttempted = true;
    try {
      final imageProvider = const AssetImage('assets/images/board_wood.png');
      // 先检查缓存，如果已预加载则同步获取
      final config = createLocalImageConfiguration(context);
      final stream = imageProvider.resolve(config);
      final completer = Completer<ui.Image>();
      final listener = ImageStreamListener((info, _) {
        if (!completer.isCompleted) completer.complete(info.image);
      });
      stream.addListener(listener);
      // 如果已缓存，listener 可能在微任务中同步触发
      final image = await completer.future;
      stream.removeListener(listener);
      if (mounted) setState(() => _bgImage = image);
    } catch (_) {
      // 图片加载失败时静默使用渐变色背景
    }
  }

  Position? _toBoardPos(Offset point) {
    final c = ((point.dx - boardPadding) / _cellSize).round();
    final r = ((point.dy - boardPadding) / _cellSize).round();
    if (c < 0 || c > 8 || r < 0 || r > 9) return null;
    return Position(c, r);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth - boardPadding * 2;
        final maxH = constraints.maxHeight - boardPadding * 2;
        final cellFromW = maxW / (boardCols - 1);
        final cellFromH = maxH / (boardRows - 1);
        _cellSize = min(cellFromW, cellFromH).clamp(20.0, 80.0);

        final totalW = boardWidth(_cellSize) + boardPadding * 2;
        final totalH = boardHeight(_cellSize) + boardPadding * 2;

        return Center(
          child: MouseRegion(
            onHover: (event) {
              if (widget.onCellHover != null) {
                final pos = _toBoardPos(event.localPosition);
                if (pos != null) widget.onCellHover!(pos);
              }
            },
            onExit: (event) {
              if (widget.onCellHover != null) widget.onCellHover!(null);
            },
            child: GestureDetector(
              key: _paintKey,
              onTapDown: (details) {
                final pos = _toBoardPos(details.localPosition);
                if (pos != null) widget.onCellTap(pos);
              },
              child: CustomPaint(
              size: Size(totalW, totalH),
              painter: ChessBoardPainter(
                board: widget.board,
                selectedPos: widget.selectedPos,
                validMoves: widget.validMoves,
                lastMove: widget.lastMove,
                animPiece: widget.animPiece,
                analysisMode: widget.analysisMode,
                analysisData: widget.analysisData,
                analysisSelectedPos: widget.analysisSelectedPos,
                playerSide: widget.playerSide,
                bgImage: _bgImage,
                cellSize: _cellSize,
                padding: boardPadding,
              ),  // ChessBoardPainter
            ),  // CustomPaint
          ),  // GestureDetector
          ),
        );
      },
    );
  }
}

/// 棋盘绘制器
class ChessBoardPainter extends CustomPainter {
  final Board board;
  final Position? selectedPos;
  final List<Position> validMoves;
  final Move? lastMove;
  final AnimationPiece? animPiece;
  final AnalysisMode analysisMode;
  final AnalysisData? analysisData;
  final Position? analysisSelectedPos;
  final Side playerSide;
  final ui.Image? bgImage;
  final double cellSize;
  final double padding;

  ChessBoardPainter({
    required this.board,
    this.selectedPos,
    this.validMoves = const [],
    this.lastMove,
    this.animPiece,
    this.analysisMode = AnalysisMode.none,
    this.analysisData,
    this.analysisSelectedPos,
    this.playerSide = Side.red,
    this.bgImage,
    required this.cellSize,
    required this.padding,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawBackground(canvas, size);
    _drawCoordinates(canvas);
    _drawGrid(canvas);
    _drawRiverText(canvas);
    _drawLastMoveHighlight(canvas);
    _drawValidMoveDots(canvas);
    _drawPieces(canvas);
    _drawCrossingSwordsOnEnemies(canvas);
    _drawFriendlyShields(canvas);
    _drawAnimatingPiece(canvas);
    _drawSelection(canvas);
    // 分析模式覆盖层（最后画，在最上层）
    _drawAnalysisOverlay(canvas);
  }

  @override
  bool shouldRepaint(ChessBoardPainter oldDelegate) =>
      board != oldDelegate.board ||
      selectedPos != oldDelegate.selectedPos ||
      validMoves != oldDelegate.validMoves ||
      lastMove != oldDelegate.lastMove ||
      animPiece != oldDelegate.animPiece ||
      analysisMode != oldDelegate.analysisMode ||
      analysisData != oldDelegate.analysisData ||
      analysisSelectedPos != oldDelegate.analysisSelectedPos ||
      bgImage != oldDelegate.bgImage;

  Offset _cellPos(int col, int row) => Offset(
        padding + col * cellSize,
        padding + row * cellSize,
      );

  void _drawBackground(Canvas canvas, Size size) {
    final bgRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(8),
    );

    if (bgImage != null) {
      canvas.save();
      canvas.clipRRect(bgRect);
      final scaleX = size.width / bgImage!.width;
      final scaleY = size.height / bgImage!.height;
      final scale = max(scaleX, scaleY);
      final sw = bgImage!.width * scale;
      final sh = bgImage!.height * scale;
      final dx = (size.width - sw) / 2;
      final dy = (size.height - sh) / 2;
      canvas.drawImageRect(
        bgImage!,
        Rect.fromLTWH(0, 0, bgImage!.width.toDouble(), bgImage!.height.toDouble()),
        Rect.fromLTWH(dx, dy, sw, sh),
        Paint(),
      );
      canvas.restore();
    } else {
      final bgPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFE8C97A),
            const Color(0xFFD4A843),
            const Color(0xFFC49A3C),
            const Color(0xFFB8892F),
          ],
        ).createShader(bgRect.outerRect);
      canvas.drawRRect(bgRect, bgPaint);
    }

    final borderPaint = Paint()
      ..color = const Color(0xFF5D3A1A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawRRect(bgRect, borderPaint);
  }

  void _drawGrid(Canvas canvas) {
    final linePaint = Paint()
      ..color = const Color(0xFF5D3A1A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    for (int r = 0; r < 10; r++) {
      final p0 = _cellPos(0, r);
      final p8 = _cellPos(8, r);
      canvas.drawLine(p0, p8, linePaint);
    }
    canvas.drawLine(_cellPos(0, 0), _cellPos(0, 9), linePaint);
    canvas.drawLine(_cellPos(8, 0), _cellPos(8, 9), linePaint);
    for (int c = 1; c <= 7; c++) {
      canvas.drawLine(_cellPos(c, 0), _cellPos(c, 4), linePaint);
      canvas.drawLine(_cellPos(c, 5), _cellPos(c, 9), linePaint);
    }
    canvas.drawLine(_cellPos(3, 7), _cellPos(5, 9), linePaint);
    canvas.drawLine(_cellPos(5, 7), _cellPos(3, 9), linePaint);
    canvas.drawLine(_cellPos(3, 0), _cellPos(5, 2), linePaint);
    canvas.drawLine(_cellPos(5, 0), _cellPos(3, 2), linePaint);
  }

  void _drawRiverText(Canvas canvas) {
    final textStyle = TextStyle(
      color: const Color(0xFF5D3A1A),
      fontSize: cellSize * 0.45,
      fontWeight: FontWeight.bold,
    );
    final midY = (4.5 * cellSize) + padding;
    final leftX = padding + 0.8 * cellSize;
    final rightX = padding + 6.2 * cellSize;

    final tp = TextPainter(
      text: TextSpan(text: '楚 河', style: textStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(leftX, midY - tp.height / 2));

    final tp2 = TextPainter(
      text: TextSpan(text: '漢 界', style: textStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    tp2.paint(canvas, Offset(rightX, midY - tp2.height / 2));
  }

  /// 画行列坐标标注
  void _drawCoordinates(Canvas canvas) {
    final coordStyle = TextStyle(
      color: const Color(0xFF5D3A1A),
      fontSize: cellSize * 0.28,
      fontWeight: FontWeight.normal,
    );

    // 列坐标（上下两行，在 padding 区域内）
    for (int c = 0; c < 9; c++) {
      final x = padding + c * cellSize;
      // 上方
      final tpTop = TextPainter(
        text: TextSpan(text: '$c', style: coordStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tpTop.paint(canvas, Offset(x - tpTop.width / 2, padding * 0.3));

      // 下方
      final tpBottom = TextPainter(
        text: TextSpan(text: '$c', style: coordStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tpBottom.paint(canvas, Offset(x - tpBottom.width / 2, padding + 9 * cellSize + padding * 0.2));
    }

    // 行坐标（左右两列，在 padding 区域内）
    for (int r = 0; r < 10; r++) {
      final y = padding + r * cellSize;
      // 左侧
      final tpLeft = TextPainter(
        text: TextSpan(text: '$r', style: coordStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tpLeft.paint(canvas, Offset(padding * 0.2, y - tpLeft.height / 2));

      // 右侧
      final tpRight = TextPainter(
        text: TextSpan(text: '$r', style: coordStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tpRight.paint(canvas, Offset(padding + 8 * cellSize + padding * 0.3, y - tpRight.height / 2));
    }
  }

  void _drawLastMoveHighlight(Canvas canvas) {
    if (lastMove == null) return;
    final paint = Paint()..color = AppColors.lastMoveHighlight;
    for (final pos in [lastMove!.from, lastMove!.to]) {
      canvas.drawCircle(_cellPos(pos.col, pos.row), cellSize * 0.45, paint);
    }
  }

  /// 画空位可走绿点（在棋子下方）
  void _drawValidMoveDots(Canvas canvas) {
    for (final pos in validMoves) {
      final target = board.at(pos);
      if (target != null) continue; // 只画空位
      final center = _cellPos(pos.col, pos.row);
      canvas.drawCircle(center, cellSize * 0.15, Paint()..color = AppColors.validMoveHint);
    }
  }

  /// 在敌方棋子上面画交叉对剑
  void _drawCrossingSwordsOnEnemies(Canvas canvas) {
    for (final pos in validMoves) {
      final target = board.at(pos);
      if (target == null) continue;
      if (selectedPos == null) continue;
      final selectedPiece = board.at(selectedPos!);
      if (selectedPiece == null) continue;
      if (target.side == selectedPiece.side) continue; // 自己人跳过
      final center = _cellPos(pos.col, pos.row);
      _drawCrossingSwords(canvas, center);
    }
  }

  /// 可吃敌方：红色交叉对剑（画在棋子上面）
  void _drawCrossingSwords(Canvas canvas, Offset center) {
    final len = cellSize * 0.75;
    final halfLen = len / 2;
    final bladeW = cellSize * 0.045;
    final guardW = cellSize * 0.06;
    final guardHalf = cellSize * 0.16;

    // 红色半透明底圈
    final bgPaint = Paint()
      ..color = const Color(0x33FF3333)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, cellSize * 0.48, bgPaint);

    // 红色外圈
    final ringPaint = Paint()
      ..color = const Color(0xCCFF3333)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawCircle(center, cellSize * 0.46, ringPaint);

    void drawSword(double angle) {
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(angle);

      // 剑刃
      final bladePaint = Paint()
        ..color = const Color(0xCCDD2222)
        ..style = PaintingStyle.fill;
      final bladePath = Path()
        ..moveTo(0, -halfLen)
        ..lineTo(-bladeW, -cellSize * 0.1)
        ..lineTo(bladeW, -cellSize * 0.1)
        ..close();
      canvas.drawPath(bladePath, bladePaint);

      // 剑刃高光
      final hlPaint = Paint()
        ..color = const Color(0xCCFF8888)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;
      canvas.drawLine(Offset(0, -halfLen), Offset(0, -cellSize * 0.1), hlPaint);

      // 护手
      final guardPaint = Paint()
        ..color = const Color(0xCCDD2222)
        ..style = PaintingStyle.fill;
      canvas.drawRect(
        Rect.fromCenter(center: Offset(0, 0), width: guardHalf * 2, height: guardW * 2),
        guardPaint,
      );

      // 剑柄
      final hiltPaint = Paint()
        ..color = const Color(0xCC5D3A1A)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(0, halfLen * 0.6),
            width: bladeW * 2.5,
            height: halfLen * 0.6,
          ),
          const Radius.circular(2),
        ),
        hiltPaint,
      );

      canvas.restore();
    }

    drawSword(-0.75);
    drawSword(0.75);
  }

  /// 被选中棋子护住的友军：绿色盾牌（画在棋子上面）
  void _drawFriendlyShields(Canvas canvas) {
    if (selectedPos == null) return;
    final selectedPiece = board.at(selectedPos!);
    if (selectedPiece == null) return;

    // 计算选中棋子护住的友军位置
    final rules = Rules(board);
    final protectedPositions = rules.getProtectedFriendlies(selectedPos!);
    if (protectedPositions.isEmpty) return;

    final shieldPaint = Paint()
      ..color = const Color(0xFF33BB33)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    for (final pos in protectedPositions) {
      final center = _cellPos(pos.col, pos.row);
      _drawShield(canvas, center, shieldPaint);
    }
  }

  /// 画盾牌（居中绿色盾形，无背景）
  void _drawShield(Canvas canvas, Offset center, Paint paint) {
    final w = cellSize * 0.22;
    final h = cellSize * 0.26;

    // 盾形路径
    final shieldPath = Path()
      ..moveTo(center.dx - w, center.dy - h * 0.15)
      ..quadraticBezierTo(center.dx - w, center.dy - h, center.dx, center.dy - h)
      ..quadraticBezierTo(center.dx + w, center.dy - h, center.dx + w, center.dy - h * 0.15)
      ..lineTo(center.dx + w, center.dy + h * 0.3)
      ..lineTo(center.dx, center.dy + h)
      ..lineTo(center.dx - w, center.dy + h * 0.3)
      ..close();

    // 边框
    canvas.drawPath(shieldPath, paint);
    // 半透明填充
    canvas.drawPath(shieldPath, Paint()
      ..color = const Color(0x2233BB33)
      ..style = PaintingStyle.fill);
    // 十字装饰
    final linePaint = Paint()
      ..color = const Color(0x9933BB33)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawLine(Offset(center.dx, center.dy - h * 0.6), Offset(center.dx, center.dy + h * 0.5), linePaint);
    canvas.drawLine(Offset(center.dx - w * 0.3, center.dy), Offset(center.dx + w * 0.3, center.dy), linePaint);
  }

  void _drawPieces(Canvas canvas) {
    for (int r = 0; r < 10; r++) {
      for (int c = 0; c < 9; c++) {
        final pos = Position(c, r);
        final piece = board.at(pos);
        if (piece == null) continue;
        // 跳过正在动画的起始位置
        if (animPiece != null && animPiece!.from == pos && animPiece!.progress < 1.0) continue;
        // 选中的棋子由 _drawSelection 绘制（带抬起效果）
        if (pos == selectedPos) continue;
        _drawPiece(canvas, _cellPos(c, r), piece, false);
      }
    }
  }

  void _drawAnimatingPiece(Canvas canvas) {
    if (animPiece == null || animPiece!.progress >= 1.0) return;
    final ap = animPiece!;
    final from = _cellPos(ap.from.col, ap.from.row);
    final to = _cellPos(ap.to.col, ap.to.row);
    final t = Curves.easeInOut.transform(ap.progress);

    // 抛物线弧线：中间最高
    final arcHeight = cellSize * 0.3;
    final arcOffset = Offset(0, -arcHeight * sin(pi * ap.progress));

    final center = Offset.lerp(from, to, t)! + arcOffset;
    _drawPiece(canvas, center, ap.piece, false);
  }

  void _drawPiece(Canvas canvas, Offset center, Piece piece, bool selected) {
    final radius = cellSize * 0.44;

    if (selected) {
      // ── 选中状态：棋子抬起 + 大阴影 ──
      final liftOffset = Offset(0, -cellSize * pieceLiftScale);
      final liftedCenter = center + liftOffset;

      // 大阴影（抬升后更远更深）
      final shadowRadius = radius * pieceSelectedShadowScale;
      canvas.drawCircle(
        center + Offset(pieceSelectedShadowOffset, pieceSelectedShadowOffset),
        shadowRadius,
        Paint()..color = const Color(0x80000000),
      );
      // 第二层阴影（边缘柔化）
      canvas.drawCircle(
        center + Offset(pieceSelectedShadowOffset + 1, pieceSelectedShadowOffset + 1),
        shadowRadius * 0.7,
        Paint()..color = const Color(0x40000000),
      );

      // 棋子上浮后的身体
      final bodyRect = Rect.fromCircle(center: liftedCenter, radius: radius);
      final bodyPaint = Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.3),
          radius: 1.0,
          colors: [AppColors.pieceBodyHighlight, AppColors.pieceBody],
        ).createShader(bodyRect);
      canvas.drawCircle(liftedCenter, radius, bodyPaint);

      // 边框：更粗更亮
      canvas.drawCircle(liftedCenter, radius, Paint()
        ..color = AppColors.pieceBorder
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0);

      // 选中光环（金色外圈）
      canvas.drawCircle(liftedCenter, radius + 3, Paint()
        ..color = AppColors.selectedHighlight
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3);

      // 内圈装饰
      canvas.drawCircle(liftedCenter, radius * 0.88, Paint()
        ..color = AppColors.pieceBorder
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0);

      _drawPieceText(canvas, liftedCenter, piece, radius);
    } else {
      // ── 普通状态 ──
      // 小阴影
      canvas.drawCircle(center + const Offset(2, 2), radius, Paint()..color = AppColors.pieceShadow);

      // 棋子身体
      final bodyRect = Rect.fromCircle(center: center, radius: radius);
      final bodyPaint = Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.3),
          radius: 1.0,
          colors: [AppColors.pieceBody, const Color(0xFFE0C89A)],
        ).createShader(bodyRect);
      canvas.drawCircle(center, radius, bodyPaint);

      // 边框
      canvas.drawCircle(center, radius, Paint()
        ..color = AppColors.pieceBorder
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5);

      // 内圈
      canvas.drawCircle(center, radius * 0.88, Paint()
        ..color = AppColors.pieceBorder
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8);

      _drawPieceText(canvas, center, piece, radius);
    }
  }

  void _drawPieceText(Canvas canvas, Offset center, Piece piece, double radius) {
    final textColor = piece.side == Side.red ? AppColors.pieceRed : AppColors.pieceBlack;
    final tp = TextPainter(
      text: TextSpan(
        text: piece.displayName,
        style: TextStyle(
          color: textColor,
          fontSize: cellSize * pieceFontScale,
          fontWeight: FontWeight.bold,
          fontFamily: 'Serif',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));
  }

  void _drawSelection(Canvas canvas) {
    if (selectedPos == null) return;
    final center = _cellPos(selectedPos!.col, selectedPos!.row);
    final piece = board.at(selectedPos!);
    if (piece != null) {
      _drawPiece(canvas, center, piece, true);
    }
  }

  /// 分析模式覆盖层
  void _drawAnalysisOverlay(Canvas canvas) {
    if (analysisMode == AnalysisMode.none || analysisData == null) return;
    // 先画敌我边框
    _drawSideBorders(canvas);
    switch (analysisMode) {
      case AnalysisMode.protection:
        _drawProtectionOverlay(canvas); break;
      case AnalysisMode.attack:
        _drawAttackOverlay(canvas); break;
      case AnalysisMode.safety:
        _drawSafetyOverlay(canvas); break;
      case AnalysisMode.danger:
        _drawDangerOverlay(canvas); break;
      default: break;
    }
  }

  /// 单元格中心（考虑选中棋子抬起偏移）
  Offset _adjCenter(int col, int row) {
    final center = _cellPos(col, row);
    if (selectedPos != null && selectedPos!.col == col && selectedPos!.row == row) {
      return center + Offset(0, -cellSize * pieceLiftScale);
    }
    return center;
  }

  /// 敌我边框：己方绿框，敌方红框
  void _drawSideBorders(Canvas canvas) {
    for (int r = 0; r < 10; r++)
      for (int c = 0; c < 9; c++) {
        final p = board.at(Position(c, r));
        if (p == null) continue;
        final center = _adjCenter(c, r);
        final isFriendly = p.side == playerSide;
        canvas.drawCircle(
          center,
          cellSize * 0.48,
          Paint()
            ..color = isFriendly ? const Color(0x4400FF00) : const Color(0x44FF0000)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5,
        );
      }
  }

  void _drawProtectionOverlay(Canvas canvas) {
    for (int r = 0; r < 10; r++)
      for (int c = 0; c < 9; c++) {
        final p = board.at(Position(c, r));
        if (p == null) continue;
        final key = r * 9 + c;
        final cnt = analysisData!.protectionCount[key] ?? 0;
        final center = _adjCenter(c, r);
        if (cnt > 0) {
          final tp = TextPainter(
            text: TextSpan(text: '$cnt', style: TextStyle(
              color: const Color(0xFF22BB22), fontSize: cellSize * 0.22, fontWeight: FontWeight.bold,
            )),
            textDirection: TextDirection.ltr,
          )..layout();
          tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy + cellSize * 0.30));
        }
        if (analysisSelectedPos != null &&
            analysisSelectedPos!.col == c && analysisSelectedPos!.row == r) {
          final prot = analysisData!.protectors[key];
          if (prot != null) {
            for (final pos in prot) {
              final pc = _cellPos(pos.col, pos.row);
              canvas.drawCircle(pc, cellSize * 0.20, Paint()..color = const Color(0xFF33BB33)..style = PaintingStyle.stroke..strokeWidth = 2);
              canvas.drawCircle(pc + Offset(cellSize * 0.06, 0), cellSize * 0.12, Paint()..color = const Color(0xFF33BB33)..style = PaintingStyle.stroke..strokeWidth = 2);
              canvas.drawCircle(pc - Offset(cellSize * 0.06, 0), cellSize * 0.12, Paint()..color = const Color(0xFF33BB33)..style = PaintingStyle.stroke..strokeWidth = 2);
              canvas.drawLine(pc - Offset(0, cellSize * 0.12), pc + Offset(0, cellSize * 0.12), Paint()..color = const Color(0xFF33BB33)..style = PaintingStyle.stroke..strokeWidth = 2);
            }
          }
        }
      }
  }

  void _drawAttackOverlay(Canvas canvas) {
    // 如果选中了棋子，计算其攻击范围
    Set<int>? selectedRange;
    if (analysisSelectedPos != null) {
      final selPiece = board.at(analysisSelectedPos!);
      if (selPiece != null) {
        final rules = Rules(board);
        final moves = rules.getRawMoves(analysisSelectedPos!);
        selectedRange = moves.map((m) => m.row * 9 + m.col).toSet();
      }
    }

    for (int r = 0; r < 10; r++)
      for (int c = 0; c < 9; c++) {
        final key = r * 9 + c;
        final pos = Position(c, r);

        // 如果选中了棋子，只显示该子攻击范围内的位置
        if (selectedRange != null && !selectedRange.contains(key)) continue;

        final piece = board.at(pos);
        final cnt = analysisData!.attackCount[key] ?? 0;
        if (cnt == 0) continue;
        final center = _adjCenter(c, r);
        if (piece == null) {
          final d = cellSize * 0.12;
          final paint = Paint()..color = const Color(0xAAFF4444)..style = PaintingStyle.stroke..strokeWidth = 1.5;
          canvas.drawLine(center - Offset(d, d), center + Offset(d, d), paint);
          canvas.drawLine(center - Offset(d, -d), center + Offset(d, -d), paint);
        } else {
          _drawCrossingSwords(canvas, center);
        }
      }
  }

  void _drawSafetyOverlay(Canvas canvas) {
    for (int r = 0; r < 10; r++)
      for (int c = 0; c < 9; c++) {
        final p = board.at(Position(c, r));
        if (p == null) continue;
        final key = r * 9 + c;
        int sc = analysisData!.safetyScore[key] ?? 0;
        final bool isFriendly = p.side == playerSide;
        if (!isFriendly) sc = -sc;
        final Color col;
        if (sc >= 3) col = const Color(0x8022BB22);
        else if (sc == 2) col = const Color(0x8044CC44);
        else if (sc == 1) col = const Color(0x8066DD66);
        else if (sc == 0) col = const Color(0x40888888);
        else if (sc == -1) col = const Color(0x80DD6666);
        else if (sc == -2) col = const Color(0x80CC4444);
        else col = const Color(0x80BB2222);
        canvas.drawCircle(_adjCenter(c, r), cellSize * 0.46, Paint()..color = col);
      }
  }

  void _drawDangerOverlay(Canvas canvas) {
    // 如果选中了敌方棋子，计算其攻击范围
    Set<int>? selectedRange;
    if (analysisSelectedPos != null) {
      final selPiece = board.at(analysisSelectedPos!);
      if (selPiece != null) {
        final rules = Rules(board);
        final moves = rules.getRawMoves(analysisSelectedPos!);
        selectedRange = moves.map((m) => m.row * 9 + m.col).toSet();
      }
    }

    for (int r = 0; r < 10; r++)
      for (int c = 0; c < 9; c++) {
        final key = r * 9 + c;

        // 如果选中了棋子，只显示该子攻击范围内的位置
        if (selectedRange != null && !selectedRange.contains(key)) continue;

        final cnt = analysisData!.dangerScore[key] ?? 0;
        if (cnt == 0) continue;
        final center = _adjCenter(c, r);

        // 炮的移动位用黄色
        final isCannonMove = analysisData!.cannonMoveOnly.contains(key);

        final Color col;
        if (isCannonMove) {
          // 炮只能移动的位置：黄色系
          if (cnt >= 4) col = const Color(0x55DDAA22);
          else if (cnt >= 2) col = const Color(0x55DDCC44);
          else col = const Color(0x55DDEE66);
        } else {
          // 正常危险位：红色系
          if (cnt >= 6) col = const Color(0x55FF2222);
          else if (cnt == 5) col = const Color(0x55FF4422);
          else if (cnt == 4) col = const Color(0x55FF6622);
          else if (cnt == 3) col = const Color(0x55FF8844);
          else if (cnt == 2) col = const Color(0x55FFAA66);
          else if (cnt == 1) col = const Color(0x55FFCC88);
          else continue;
        }
        canvas.drawRect(Rect.fromCenter(center: center, width: cellSize * 0.9, height: cellSize * 0.9), Paint()..color = col);
      }
  }
}
