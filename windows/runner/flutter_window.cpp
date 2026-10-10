#include "flutter_window.h"

#include <optional>
#include <vector>

#include <flutter/standard_method_codec.h>
#include <wincrypt.h>

#include "flutter/generated_plugin_registrant.h"

namespace {

bool ProtectForCurrentUser(const std::vector<uint8_t>& input,
                           std::vector<uint8_t>* output) {
  DATA_BLOB input_blob{};
  input_blob.cbData = static_cast<DWORD>(input.size());
  input_blob.pbData = const_cast<BYTE*>(input.data());
  DATA_BLOB output_blob{};
  if (!CryptProtectData(&input_blob, L"Lunarr Jellyfin credentials", nullptr,
                        nullptr, nullptr, CRYPTPROTECT_UI_FORBIDDEN,
                        &output_blob)) {
    return false;
  }
  output->assign(output_blob.pbData, output_blob.pbData + output_blob.cbData);
  LocalFree(output_blob.pbData);
  return true;
}

bool UnprotectForCurrentUser(const std::vector<uint8_t>& input,
                             std::vector<uint8_t>* output) {
  DATA_BLOB input_blob{};
  input_blob.cbData = static_cast<DWORD>(input.size());
  input_blob.pbData = const_cast<BYTE*>(input.data());
  DATA_BLOB output_blob{};
  if (!CryptUnprotectData(&input_blob, nullptr, nullptr, nullptr, nullptr,
                          CRYPTPROTECT_UI_FORBIDDEN, &output_blob)) {
    return false;
  }
  output->assign(output_blob.pbData, output_blob.pbData + output_blob.cbData);
  LocalFree(output_blob.pbData);
  return true;
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  secure_credentials_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(),
          "lunarr/secure_credentials",
          &flutter::StandardMethodCodec::GetInstance());
  secure_credentials_channel_->SetMethodCallHandler(
      [](const auto& call, auto result) {
        const auto* input = std::get_if<std::vector<uint8_t>>(call.arguments());
        if (input == nullptr) {
          result->Error("invalid_arguments", "Expected binary credentials.");
          return;
        }
        std::vector<uint8_t> output;
        const bool succeeded = call.method_name() == "protect"
            ? ProtectForCurrentUser(*input, &output)
            : call.method_name() == "unprotect"
            ? UnprotectForCurrentUser(*input, &output)
            : false;
        if (!succeeded) {
          if (call.method_name() != "protect" &&
              call.method_name() != "unprotect") {
            result->NotImplemented();
          } else {
            result->Error("dpapi_failed", "Windows could not protect credentials.");
          }
          return;
        }
        result->Success(flutter::EncodableValue(output));
      });
  fullscreen_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "lunarr/fullscreen",
          &flutter::StandardMethodCodec::GetInstance());
  fullscreen_channel_->SetMethodCallHandler(
      [this](const auto& call, auto result) {
        if (call.method_name() == "prepare") {
          const auto* enabled = std::get_if<bool>(call.arguments());
          if (enabled == nullptr) {
            result->Error("invalid_arguments", "Expected fullscreen state.");
            return;
          }
          if (*enabled && !fullscreen_geometry_active_) {
            fullscreen_placement_.length = sizeof(fullscreen_placement_);
            if (!GetWindowPlacement(GetHandle(), &fullscreen_placement_)) {
              result->Error("fullscreen_failed", "Could not save placement.");
              return;
            }
            fullscreen_style_ = GetWindowLongPtr(GetHandle(), GWL_STYLE);
            fullscreen_placement_saved_ = true;
            fullscreen_monitor_ =
                MonitorFromWindow(GetHandle(), MONITOR_DEFAULTTONEAREST);
          }
          fullscreen_geometry_active_ = *enabled;
          result->Success();
        } else if (call.method_name() == "fit") {
          if (!fullscreen_geometry_active_ || !FitFullscreenMonitor()) {
            result->Error("fullscreen_failed", "Could not fit the monitor.");
          } else {
            result->Success();
          }
        } else if (call.method_name() == "restore") {
          if (fullscreen_placement_saved_) {
            SetWindowLongPtr(GetHandle(), GWL_STYLE, fullscreen_style_);
            if (!SetWindowPlacement(GetHandle(), &fullscreen_placement_)) {
              result->Error("fullscreen_failed", "Could not restore placement.");
              return;
            }
            SetWindowPos(GetHandle(), nullptr, 0, 0, 0, 0,
                         SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER |
                         SWP_NOACTIVATE | SWP_FRAMECHANGED);
            fullscreen_placement_saved_ = false;
          }
          result->Success();
        } else {
          result->NotImplemented();
        }
      });
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Fullscreen has no non-client inset. window_manager's frameless adjustment
  // otherwise uses rcWork (excluding the taskbar) and can leave desktop edges.
  if (fullscreen_geometry_active_ && message == WM_NCCALCSIZE && wparam) {
    return 0;
  }

  if (fullscreen_geometry_active_ && message == WM_GETMINMAXINFO) {
    MONITORINFO monitor{};
    monitor.cbSize = sizeof(monitor);
    if (GetMonitorInfo(fullscreen_monitor_, &monitor)) {
      auto* info = reinterpret_cast<MINMAXINFO*>(lparam);
      info->ptMinTrackSize = {0, 0};
      info->ptMaxTrackSize = {
          monitor.rcMonitor.right - monitor.rcMonitor.left,
          monitor.rcMonitor.bottom - monitor.rcMonitor.top};
      return 0;
    }
  }

  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  if (fullscreen_geometry_active_ &&
      (message == WM_DPICHANGED || message == WM_DISPLAYCHANGE)) {
    // Plugins first receive the new DPI. Ignore Windows' suggested logical
    // rectangle and fit the full physical monitor instead.
    if (message == WM_DISPLAYCHANGE) {
      fullscreen_monitor_ = MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST);
    }
    FitFullscreenMonitor();
    return 0;
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}

bool FlutterWindow::FitFullscreenMonitor() {
  MONITORINFO monitor{};
  monitor.cbSize = sizeof(monitor);
  if (!GetMonitorInfo(fullscreen_monitor_, &monitor)) {
    fullscreen_monitor_ =
        MonitorFromWindow(GetHandle(), MONITOR_DEFAULTTONEAREST);
    if (!GetMonitorInfo(fullscreen_monitor_, &monitor)) return false;
  }
  const HWND window = GetHandle();
  const auto style = GetWindowLongPtr(window, GWL_STYLE);
  // A maximized window is constrained to the work area. Keep window_manager's
  // saved placement/style for exit, but remove that constraint while fullscreen.
  SetWindowLongPtr(window, GWL_STYLE,
                   style & ~(WS_CAPTION | WS_THICKFRAME | WS_MAXIMIZE |
                             WS_MINIMIZE));
  return SetWindowPos(window, HWND_TOP, monitor.rcMonitor.left,
                      monitor.rcMonitor.top,
                      monitor.rcMonitor.right - monitor.rcMonitor.left,
                      monitor.rcMonitor.bottom - monitor.rcMonitor.top,
                      SWP_NOOWNERZORDER | SWP_FRAMECHANGED) != FALSE;
}
