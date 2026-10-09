#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>
#include <windows.h>
#include <shellapi.h>

#include <memory>
#include <string>

#include "win32_window.h"

// Hosts the Flutter view and owns the notification-area (tray) icon:
// closing the window hides it to the tray so the phone stays reachable.
class FlutterWindow : public Win32Window {
 public:
  // |start_hidden|: started with --minimized (e.g. autostart) -> tray only.
  FlutterWindow(const flutter::DartProject& project, bool start_hidden);
  virtual ~FlutterWindow();

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  using EncodableValue = flutter::EncodableValue;

  void AddTrayIcon();
  void UpdateTrayIcon();
  void RemoveTrayIcon();
  void ShowBalloon(const std::wstring& title, const std::wstring& text);
  void ShowFromTray();
  void ShowTrayMenu();
  void QuitApp();
  void HandleTrayCall(
      const flutter::MethodCall<EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<EncodableValue>> result);

  flutter::DartProject project_;
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;
  std::unique_ptr<flutter::MethodChannel<EncodableValue>> tray_channel_;

  bool start_hidden_;
  bool close_to_tray_ = true;
  bool quitting_ = false;
  bool online_ = false;
  bool tray_added_ = false;
  bool hint_shown_ = false;
  UINT taskbar_created_ = 0;

  // Localised texts are sent by the app (English defaults until then).
  std::wstring tooltip_ = L"Haustelefon";
  std::wstring label_open_ = L"Open";
  std::wstring label_quit_ = L"Quit";
  std::wstring hidden_title_ = L"Haustelefon keeps running";
  std::wstring hidden_text_ = L"You stay reachable. Quit from the tray icon.";
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
