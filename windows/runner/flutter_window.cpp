#include "flutter_window.h"

#include <flutter/standard_method_codec.h>

#include <optional>

#include "flutter/generated_plugin_registrant.h"
#include "resource.h"

namespace {

constexpr UINT kTrayMessage = WM_APP + 1;
constexpr UINT kTrayId = 1;
constexpr UINT kMenuOpen = 1001;
constexpr UINT kMenuQuit = 1002;
constexpr wchar_t kRunKey[] =
    L"Software\\Microsoft\\Windows\\CurrentVersion\\Run";
constexpr wchar_t kRunValue[] = L"Haustelefon";

std::wstring Widen(const std::string& utf8) {
  if (utf8.empty()) return std::wstring();
  int len = ::MultiByteToWideChar(CP_UTF8, 0, utf8.data(),
                                  static_cast<int>(utf8.size()), nullptr, 0);
  std::wstring out(len, L'\0');
  ::MultiByteToWideChar(CP_UTF8, 0, utf8.data(), static_cast<int>(utf8.size()),
                        out.data(), len);
  return out;
}

// Reads a string/bool entry from a method-call argument map.
const flutter::EncodableValue* Arg(const flutter::EncodableMap& map,
                                   const char* key) {
  auto it = map.find(flutter::EncodableValue(key));
  return it == map.end() ? nullptr : &it->second;
}

bool ReadString(const flutter::EncodableMap& map, const char* key,
                std::wstring* out) {
  const auto* v = Arg(map, key);
  if (v == nullptr) return false;
  if (const auto* s = std::get_if<std::string>(v)) {
    *out = Widen(*s);
    return true;
  }
  return false;
}

bool ReadBool(const flutter::EncodableMap& map, const char* key, bool* out) {
  const auto* v = Arg(map, key);
  if (v == nullptr) return false;
  if (const auto* b = std::get_if<bool>(v)) {
    *out = *b;
    return true;
  }
  return false;
}

void CopyText(wchar_t* dst, size_t capacity, const std::wstring& src) {
  wcsncpy_s(dst, capacity, src.c_str(), _TRUNCATE);
}

std::wstring AutostartCommand() {
  wchar_t path[MAX_PATH];
  ::GetModuleFileNameW(nullptr, path, MAX_PATH);
  return L"\"" + std::wstring(path) + L"\" --minimized";
}

bool IsAutostartEnabled() {
  DWORD size = 0;
  return ::RegGetValueW(HKEY_CURRENT_USER, kRunKey, kRunValue, RRF_RT_REG_SZ,
                        nullptr, nullptr, &size) == ERROR_SUCCESS;
}

bool SetAutostart(bool enabled) {
  if (!enabled) {
    LSTATUS s = ::RegDeleteKeyValueW(HKEY_CURRENT_USER, kRunKey, kRunValue);
    return s == ERROR_SUCCESS || s == ERROR_FILE_NOT_FOUND;
  }
  std::wstring cmd = AutostartCommand();
  return ::RegSetKeyValueW(
             HKEY_CURRENT_USER, kRunKey, kRunValue, REG_SZ, cmd.c_str(),
             static_cast<DWORD>((cmd.size() + 1) * sizeof(wchar_t))) ==
         ERROR_SUCCESS;
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project,
                             bool start_hidden)
    : project_(project), start_hidden_(start_hidden) {}

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
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  // Tray channel: the app sends texts/status, asks for autostart etc.
  tray_channel_ = std::make_unique<flutter::MethodChannel<EncodableValue>>(
      flutter_controller_->engine()->messenger(), "de.haustelefon/tray",
      &flutter::StandardMethodCodec::GetInstance());
  tray_channel_->SetMethodCallHandler(
      [this](const auto& call, auto result) {
        HandleTrayCall(call, std::move(result));
      });

  taskbar_created_ = ::RegisterWindowMessageW(L"TaskbarCreated");
  AddTrayIcon();

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    // Started via autostart (--minimized): stay in the tray.
    if (!start_hidden_) this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  RemoveTrayIcon();
  tray_channel_ = nullptr;
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

void FlutterWindow::AddTrayIcon() {
  NOTIFYICONDATAW nid = {};
  nid.cbSize = sizeof(nid);
  nid.hWnd = GetHandle();
  nid.uID = kTrayId;
  nid.uFlags = NIF_ICON | NIF_MESSAGE | NIF_TIP;
  nid.uCallbackMessage = kTrayMessage;
  nid.hIcon = static_cast<HICON>(::LoadImageW(
      ::GetModuleHandleW(nullptr),
      MAKEINTRESOURCEW(online_ ? IDI_TRAY_ONLINE : IDI_TRAY_OFFLINE),
      IMAGE_ICON, ::GetSystemMetrics(SM_CXSMICON),
      ::GetSystemMetrics(SM_CYSMICON), LR_DEFAULTCOLOR));
  CopyText(nid.szTip, ARRAYSIZE(nid.szTip), tooltip_);
  tray_added_ = ::Shell_NotifyIconW(tray_added_ ? NIM_MODIFY : NIM_ADD, &nid);
  if (nid.hIcon) ::DestroyIcon(nid.hIcon);
}

void FlutterWindow::UpdateTrayIcon() { AddTrayIcon(); }

void FlutterWindow::RemoveTrayIcon() {
  if (!tray_added_) return;
  NOTIFYICONDATAW nid = {};
  nid.cbSize = sizeof(nid);
  nid.hWnd = GetHandle();
  nid.uID = kTrayId;
  ::Shell_NotifyIconW(NIM_DELETE, &nid);
  tray_added_ = false;
}

void FlutterWindow::ShowBalloon(const std::wstring& title,
                                const std::wstring& text) {
  if (!tray_added_) return;
  NOTIFYICONDATAW nid = {};
  nid.cbSize = sizeof(nid);
  nid.hWnd = GetHandle();
  nid.uID = kTrayId;
  nid.uFlags = NIF_INFO;
  nid.dwInfoFlags = NIIF_INFO;
  CopyText(nid.szInfoTitle, ARRAYSIZE(nid.szInfoTitle), title);
  CopyText(nid.szInfo, ARRAYSIZE(nid.szInfo), text);
  ::Shell_NotifyIconW(NIM_MODIFY, &nid);
}

void FlutterWindow::ShowFromTray() {
  HWND hwnd = GetHandle();
  ::ShowWindow(hwnd, SW_SHOW);
  if (::IsIconic(hwnd)) ::ShowWindow(hwnd, SW_RESTORE);
  ::SetForegroundWindow(hwnd);
}

void FlutterWindow::ShowTrayMenu() {
  HMENU menu = ::CreatePopupMenu();
  ::AppendMenuW(menu, MF_STRING, kMenuOpen, label_open_.c_str());
  ::AppendMenuW(menu, MF_SEPARATOR, 0, nullptr);
  ::AppendMenuW(menu, MF_STRING, kMenuQuit, label_quit_.c_str());
  ::SetMenuDefaultItem(menu, kMenuOpen, FALSE);

  POINT pt;
  ::GetCursorPos(&pt);
  HWND hwnd = GetHandle();
  // Required so the menu closes when clicking elsewhere.
  ::SetForegroundWindow(hwnd);
  UINT cmd = ::TrackPopupMenu(menu, TPM_RETURNCMD | TPM_RIGHTBUTTON |
                                        TPM_BOTTOMALIGN | TPM_RIGHTALIGN,
                              pt.x, pt.y, 0, hwnd, nullptr);
  ::PostMessageW(hwnd, WM_NULL, 0, 0);
  ::DestroyMenu(menu);

  if (cmd == kMenuOpen) ShowFromTray();
  if (cmd == kMenuQuit) QuitApp();
}

void FlutterWindow::QuitApp() {
  quitting_ = true;
  RemoveTrayIcon();
  ::DestroyWindow(GetHandle());
}

void FlutterWindow::HandleTrayCall(
    const flutter::MethodCall<EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<EncodableValue>> result) {
  const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
  const std::string& method = call.method_name();

  if (method == "configure" && args) {
    ReadString(*args, "tooltip", &tooltip_);
    ReadString(*args, "open", &label_open_);
    ReadString(*args, "quit", &label_quit_);
    ReadString(*args, "hiddenTitle", &hidden_title_);
    ReadString(*args, "hiddenText", &hidden_text_);
    ReadBool(*args, "closeToTray", &close_to_tray_);
    UpdateTrayIcon();
    result->Success();
  } else if (method == "setStatus" && args) {
    ReadBool(*args, "online", &online_);
    ReadString(*args, "tooltip", &tooltip_);
    UpdateTrayIcon();
    result->Success();
  } else if (method == "notify" && args) {
    std::wstring title, text;
    ReadString(*args, "title", &title);
    ReadString(*args, "text", &text);
    ShowBalloon(title, text);
    result->Success();
  } else if (method == "show") {
    ShowFromTray();
    result->Success();
  } else if (method == "isAutostart") {
    result->Success(EncodableValue(IsAutostartEnabled()));
  } else if (method == "setAutostart" && args) {
    bool enabled = false;
    ReadBool(*args, "enabled", &enabled);
    result->Success(EncodableValue(SetAutostart(enabled)));
  } else {
    result->NotImplemented();
  }
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

  if (taskbar_created_ != 0 && message == taskbar_created_) {
    // Explorer restarted: the tray icon is gone and must be added again.
    tray_added_ = false;
    AddTrayIcon();
    return 0;
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
    case WM_CLOSE:
      // "X" hides to the tray instead of quitting, so calls still arrive.
      if (close_to_tray_ && !quitting_ && tray_added_) {
        ::ShowWindow(hwnd, SW_HIDE);
        if (!hint_shown_) {
          hint_shown_ = true;
          ShowBalloon(hidden_title_, hidden_text_);
        }
        return 0;
      }
      break;
    case kTrayMessage:
      switch (LOWORD(lparam)) {
        case WM_LBUTTONUP:
        case WM_LBUTTONDBLCLK:
          ShowFromTray();
          return 0;
        case WM_RBUTTONUP:
        case WM_CONTEXTMENU:
          ShowTrayMenu();
          return 0;
      }
      return 0;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
