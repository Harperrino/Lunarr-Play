import 'package:flutter/material.dart';

/// Owns and synchronizes the five scroll positions used by the desktop EPG.
class EpgScrollCoordinator {
  EpgScrollCoordinator() {
    horizontalBody.addListener(syncHorizontalFollowersFromBody);
    horizontalHeader.addListener(syncHorizontalBodyFromHeader);
    horizontalTrack.addListener(syncHorizontalBodyFromTrack);
    verticalChannels.addListener(syncProgramScrollFromChannel);
    verticalPrograms.addListener(syncChannelScrollFromProgram);
  }

  final ScrollController horizontalBody = ScrollController();
  final ScrollController horizontalHeader = ScrollController();
  final ScrollController horizontalTrack = ScrollController();
  final ScrollController verticalChannels = ScrollController();
  final ScrollController verticalPrograms = ScrollController();

  bool _syncingHorizontal = false;
  bool _syncingVertical = false;

  static double scaledOffsetForZoom(
    double offset,
    double oldPixelsPerMinute,
    double newPixelsPerMinute,
  ) {
    if (oldPixelsPerMinute <= 0 || oldPixelsPerMinute == newPixelsPerMinute) {
      return offset;
    }
    return offset * (newPixelsPerMinute / oldPixelsPerMinute);
  }

  void syncProgramScrollFromChannel() {
    if (_syncingVertical || !verticalPrograms.hasClients) return;
    _syncingVertical = true;
    verticalPrograms.jumpTo(verticalChannels.offset);
    _syncingVertical = false;
  }

  void syncChannelScrollFromProgram() {
    if (_syncingVertical || !verticalChannels.hasClients) return;
    _syncingVertical = true;
    verticalChannels.jumpTo(verticalPrograms.offset);
    _syncingVertical = false;
  }

  void syncHorizontalFollowersFromBody() {
    if (_syncingHorizontal) return;
    _syncingHorizontal = true;
    final offset = horizontalBody.offset;
    _jumpIfNeeded(horizontalHeader, offset);
    _jumpIfNeeded(horizontalTrack, offset);
    _syncingHorizontal = false;
  }

  void syncHorizontalBodyFromHeader() {
    if (_syncingHorizontal || !horizontalBody.hasClients) return;
    _syncingHorizontal = true;
    horizontalBody.jumpTo(horizontalHeader.offset);
    _syncingHorizontal = false;
  }

  void syncHorizontalBodyFromTrack() {
    if (_syncingHorizontal || !horizontalBody.hasClients) return;
    _syncingHorizontal = true;
    horizontalBody.jumpTo(horizontalTrack.offset);
    _syncingHorizontal = false;
  }

  void scrollHorizontalBy(double delta) {
    if (delta == 0 || !horizontalBody.hasClients) return;
    final position = horizontalBody.position;
    horizontalBody.jumpTo(
      (position.pixels + delta).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      ),
    );
  }

  void _jumpIfNeeded(ScrollController controller, double offset) {
    if (controller.hasClients && (controller.offset - offset).abs() > 0.5) {
      controller.jumpTo(offset);
    }
  }

  void dispose() {
    horizontalBody.removeListener(syncHorizontalFollowersFromBody);
    horizontalHeader.removeListener(syncHorizontalBodyFromHeader);
    horizontalTrack.removeListener(syncHorizontalBodyFromTrack);
    verticalChannels.removeListener(syncProgramScrollFromChannel);
    verticalPrograms.removeListener(syncChannelScrollFromProgram);
    horizontalBody.dispose();
    horizontalHeader.dispose();
    horizontalTrack.dispose();
    verticalChannels.dispose();
    verticalPrograms.dispose();
  }
}
