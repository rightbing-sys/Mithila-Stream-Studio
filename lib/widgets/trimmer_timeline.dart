import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/export_service.dart';

class TrimmerTimeline extends StatefulWidget {
  final Duration totalDuration;
  final Duration startTrim;
  final Duration endTrim;
  final Duration currentPosition;
  final ValueChanged<Duration> onStartTrimChanged;
  final ValueChanged<Duration> onEndTrimChanged;
  final ValueChanged<Duration> onSeek;
  final VoidCallback? onDragStart;
  final VoidCallback? onDragEnd;
  final Duration minTrimDuration;

  const TrimmerTimeline({
    super.key,
    required this.totalDuration,
    required this.startTrim,
    required this.endTrim,
    required this.currentPosition,
    required this.onStartTrimChanged,
    required this.onEndTrimChanged,
    required this.onSeek,
    this.onDragStart,
    this.onDragEnd,
    this.minTrimDuration = const Duration(milliseconds: 500),
  });

  @override
  State<TrimmerTimeline> createState() => _TrimmerTimelineState();
}

class _TrimmerTimelineState extends State<TrimmerTimeline> {
  static const double _handleWidth = 18.0;
  bool _isScrubbing = false;

  void _scrubToLocalX(double localDx, double trackWidth, double totalMs) {
    if (trackWidth <= 0 || totalMs <= 0) return;
    final clampedX = (localDx - _handleWidth).clamp(0.0, trackWidth);
    final ratio = clampedX / trackWidth;
    final targetMs = (ratio * totalMs).round();
    widget.onSeek(Duration(milliseconds: targetMs));
  }

  @override
  Widget build(BuildContext context) {
    if (widget.totalDuration.inMilliseconds <= 0) {
      return const SizedBox(
        height: 80,
        child: Center(
          child: Text(
            'Load a video to activate trimmer',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final trackWidth = math.max(1.0, totalWidth - (_handleWidth * 2));
        final totalMs = widget.totalDuration.inMilliseconds.toDouble();

        // Calculate handle & scrubber positions
        final startMs = widget.startTrim.inMilliseconds.toDouble().clamp(0.0, totalMs);
        final endMs = widget.endTrim.inMilliseconds.toDouble().clamp(0.0, totalMs);
        final currentMs = widget.currentPosition.inMilliseconds.toDouble().clamp(0.0, totalMs);

        final startFraction = (startMs / totalMs).clamp(0.0, 1.0);
        final endFraction = (endMs / totalMs).clamp(0.0, 1.0);
        final currentFraction = (currentMs / totalMs).clamp(0.0, 1.0);

        final leftHandlePos = startFraction * trackWidth;
        final rightHandlePos = _handleWidth + (endFraction * trackWidth);
        final playheadPos = _handleWidth + (currentFraction * trackWidth);

        final clipDuration = widget.endTrim > widget.startTrim
            ? widget.endTrim - widget.startTrim
            : Duration.zero;
        final rawClipOffset = widget.currentPosition - widget.startTrim;
        final clipPosition = rawClipOffset < Duration.zero
            ? Duration.zero
            : (rawClipOffset > clipDuration ? clipDuration : rawClipOffset);

        // Active played portion within the trimmed clip
        final playedStartFraction = startFraction;
        final playedEndFraction = currentFraction.clamp(startFraction, endFraction);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Timecode badges header: IN, CLIP POSITION / DURATION, VIDEO DURATION, OUT
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 4.0),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                runSpacing: 4,
                children: [
                  _buildTimeBadge(
                    label: 'IN',
                    duration: widget.startTrim,
                    color: const Color(0xFF38BDF8),
                  ),
                  _buildClipPositionBadge(
                    clipPosition: clipPosition,
                    clipDuration: clipDuration,
                  ),
                  _buildVideoDurationBadge(
                    totalDuration: widget.totalDuration,
                  ),
                  _buildTimeBadge(
                    label: 'OUT',
                    duration: widget.endTrim,
                    color: const Color(0xFFF59E0B),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // Main interactive timeline strip & draggable scrubber
            SizedBox(
              height: 72,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (details) {
                  _scrubToLocalX(details.localPosition.dx, trackWidth, totalMs);
                },
                onHorizontalDragStart: (details) {
                  setState(() => _isScrubbing = true);
                  widget.onDragStart?.call();
                  _scrubToLocalX(details.localPosition.dx, trackWidth, totalMs);
                },
                onHorizontalDragUpdate: (details) {
                  _scrubToLocalX(details.localPosition.dx, trackWidth, totalMs);
                },
                onHorizontalDragEnd: (_) {
                  setState(() => _isScrubbing = false);
                  widget.onDragEnd?.call();
                },
                onHorizontalDragCancel: () {
                  setState(() => _isScrubbing = false);
                  widget.onDragEnd?.call();
                },
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Base filmstrip background with frame ticks
                    Positioned.fill(
                      left: _handleWidth,
                      right: _handleWidth,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF334155), width: 1),
                        ),
                        child: CustomPaint(
                          painter: FilmstripPatternPainter(
                            totalDuration: widget.totalDuration,
                          ),
                        ),
                      ),
                    ),

                    // Dimmed area before Start Handle
                    Positioned(
                      left: _handleWidth,
                      width: startFraction * trackWidth,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.65),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(6),
                            bottomLeft: Radius.circular(6),
                          ),
                        ),
                      ),
                    ),

                    // Dimmed area after End Handle
                    Positioned(
                      left: rightHandlePos,
                      right: _handleWidth,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.65),
                          borderRadius: const BorderRadius.only(
                            topRight: Radius.circular(6),
                            bottomRight: Radius.circular(6),
                          ),
                        ),
                      ),
                    ),

                    // Played clip progress fill inside trim region
                    Positioned(
                      left: _handleWidth + (playedStartFraction * trackWidth),
                      width: ((playedEndFraction - playedStartFraction) * trackWidth)
                          .clamp(0.0, trackWidth),
                      top: 2,
                      bottom: 2,
                      child: Container(
                        color: const Color(0xFF38BDF8).withOpacity(0.18),
                      ),
                    ),

                    // Active trimmed region highlight border
                    Positioned(
                      left: leftHandlePos + _handleWidth,
                      width: ((endFraction - startFraction) * trackWidth).clamp(0.0, trackWidth),
                      top: 0,
                      bottom: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.symmetric(
                            horizontal: BorderSide(
                              color: const Color(0xFF38BDF8).withOpacity(0.9),
                              width: 2.5,
                            ),
                          ),
                          color: const Color(0xFF38BDF8).withOpacity(0.06),
                        ),
                      ),
                    ),

                    // Floating live scrubber tooltip while scrubbing
                    if (_isScrubbing)
                      Positioned(
                        left: (playheadPos - 36).clamp(0.0, math.max(0.0, totalWidth - 72)),
                        top: -24,
                        child: IgnorePointer(
                          child: Container(
                            width: 72,
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF38BDF8),
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: const [
                                BoxShadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 2)),
                              ],
                            ),
                            child: Text(
                              ExportService.formatDuration(widget.currentPosition),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ),
                        ),
                      ),

                    // Playhead / Scrubber needle & thumb (driven by outer track GestureDetector for 1:1 tracking)
                    Positioned(
                      left: playheadPos - 10,
                      top: -6,
                      bottom: -6,
                      width: 20,
                      child: IgnorePointer(
                        child: Column(
                          children: [
                            Container(
                              width: _isScrubbing ? 14 : 12,
                              height: 10,
                              decoration: BoxDecoration(
                                color: _isScrubbing ? const Color(0xFF38BDF8) : Colors.white,
                                borderRadius: const BorderRadius.all(Radius.circular(3)),
                                boxShadow: const [
                                  BoxShadow(color: Colors.black54, blurRadius: 3),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Container(
                                width: _isScrubbing ? 2.5 : 2,
                                color: _isScrubbing ? const Color(0xFF38BDF8) : Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Left Drag Handle (Start Trim)
                    Positioned(
                      left: leftHandlePos,
                      top: 0,
                      bottom: 0,
                      width: _handleWidth,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onHorizontalDragStart: (_) => widget.onDragStart?.call(),
                        onHorizontalDragEnd: (_) => widget.onDragEnd?.call(),
                        onHorizontalDragUpdate: (details) {
                          final currentLeft = leftHandlePos + details.delta.dx;
                          final newFraction = (currentLeft / trackWidth).clamp(0.0, 1.0);
                          final newMs = (newFraction * totalMs).round();
                          final maxStartMs = widget.endTrim.inMilliseconds -
                              widget.minTrimDuration.inMilliseconds;

                          final clampedMs = newMs.clamp(0, maxStartMs.clamp(0, totalMs.toInt()));
                          final newDuration = Duration(milliseconds: clampedMs);

                          widget.onStartTrimChanged(newDuration);
                          widget.onSeek(newDuration);
                        },
                        child: _buildHandle(
                          isLeft: true,
                          color: const Color(0xFF38BDF8),
                        ),
                      ),
                    ),

                    // Right Drag Handle (End Trim)
                    Positioned(
                      left: rightHandlePos - _handleWidth,
                      top: 0,
                      bottom: 0,
                      width: _handleWidth,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onHorizontalDragStart: (_) => widget.onDragStart?.call(),
                        onHorizontalDragEnd: (_) => widget.onDragEnd?.call(),
                        onHorizontalDragUpdate: (details) {
                          final currentRight = (rightHandlePos - _handleWidth) + details.delta.dx;
                          final newFraction = (currentRight / trackWidth).clamp(0.0, 1.0);
                          final newMs = (newFraction * totalMs).round();
                          final minEndMs = widget.startTrim.inMilliseconds +
                              widget.minTrimDuration.inMilliseconds;

                          final clampedMs = newMs.clamp(minEndMs, totalMs.toInt());
                          final newDuration = Duration(milliseconds: clampedMs);

                          widget.onEndTrimChanged(newDuration);
                          widget.onSeek(newDuration);
                        },
                        child: _buildHandle(
                          isLeft: false,
                          color: const Color(0xFFF59E0B),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 6),

            // Time ruler / markers with Scrubber Position & Video Duration
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: _handleWidth),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '00:00.0',
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                  ),
                  Text(
                    'POS ${ExportService.formatDuration(widget.currentPosition)}',
                    style: const TextStyle(
                      fontSize: 10,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF38BDF8),
                    ),
                  ),
                  Text(
                    ExportService.formatDuration(widget.totalDuration),
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHandle({required bool isLeft, required Color color}) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(isLeft ? 6 : 0),
          bottomLeft: Radius.circular(isLeft ? 6 : 0),
          topRight: Radius.circular(!isLeft ? 6 : 0),
          bottomRight: Radius.circular(!isLeft ? 6 : 0),
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.4),
            blurRadius: 4,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 3,
              height: 14,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(1.5),
              ),
            ),
            const SizedBox(height: 3),
            Container(
              width: 3,
              height: 14,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeBadge({
    required String label,
    required Duration duration,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label ',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            ExportService.formatDuration(duration),
            style: const TextStyle(
              fontSize: 10.5,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClipPositionBadge({
    required Duration clipPosition,
    required Duration clipDuration,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.5), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timelapse, size: 11, color: Color(0xFF10B981)),
          const SizedBox(width: 4),
          Text(
            'CLIP ${ExportService.formatDuration(clipPosition)} / ${ExportService.formatDuration(clipDuration)}',
            style: const TextStyle(
              fontSize: 10.5,
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
              color: Color(0xFF10B981),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoDurationBadge({required Duration totalDuration}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334155), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.movie_outlined, size: 11, color: Colors.white70),
          const SizedBox(width: 4),
          Text(
            'VIDEO ${ExportService.formatDuration(totalDuration)}',
            style: const TextStyle(
              fontSize: 10,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w600,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }
}

class FilmstripPatternPainter extends CustomPainter {
  final Duration totalDuration;

  FilmstripPatternPainter({required this.totalDuration});

  @override
  void paint(Canvas canvas, Size size) {
    final tickPaint = Paint()
      ..color = const Color(0xFF334155).withOpacity(0.7)
      ..strokeWidth = 1.0;

    final sprocketPaint = Paint()
      ..color = const Color(0xFF0F172A)
      ..style = PaintingStyle.fill;

    // Draw simulated filmstrip frame divisions
    const frameWidth = 24.0;
    final frameCount = (size.width / frameWidth).floor();

    for (int i = 0; i < frameCount; i++) {
      final x = i * frameWidth;

      // Draw top sprocket hole
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x + 4, 3, 10, 5),
          const Radius.circular(1.5),
        ),
        sprocketPaint,
      );

      // Draw bottom sprocket hole
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x + 4, size.height - 8, 10, 5),
          const Radius.circular(1.5),
        ),
        sprocketPaint,
      );

      // Draw vertical divider
      canvas.drawLine(
        Offset(x, 10),
        Offset(x, size.height - 10),
        tickPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant FilmstripPatternPainter oldDelegate) {
    return oldDelegate.totalDuration != totalDuration;
  }
}
