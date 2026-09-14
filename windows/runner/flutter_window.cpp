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
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
