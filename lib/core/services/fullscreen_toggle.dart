/// Returns the target window fullscreen state after toggling from [actualOsFullscreen].
bool resolveFullscreenToggleTarget({required bool actualOsFullscreen}) {
  return !actualOsFullscreen;
}

/// Whether the Live immersive layout (full-bleed video, no sidebar) should be active.
bool resolveImmersiveLayout({
  required bool isDesktop,
  required bool isWindowFullscreen,
  required int activeSidebarIndex,
}) {
  if (!isDesktop) return false;
  if (!isWindowFullscreen) return false;
  return activeSidebarIndex == 0;
}
