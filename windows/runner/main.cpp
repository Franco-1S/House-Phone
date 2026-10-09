#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Nur eine Instanz: Zwei Fenster wuerden sich gegenseitig die Einstellungs-
  // datei ueberschreiben und sich mit demselben SIP-Benutzer abmelden.
  // Ein zweiter Start holt stattdessen das vorhandene Fenster nach vorne.
  // --minimized (Autostart): nur im Infobereich starten, Fenster versteckt.
  const bool start_hidden =
      command_line != nullptr && wcsstr(command_line, L"--minimized") != nullptr;
  ::CreateMutexW(nullptr, TRUE, L"Local\\Haustelefon.SingleInstance");
  if (::GetLastError() == ERROR_ALREADY_EXISTS) {
    HWND existing =
        ::FindWindowW(L"FLUTTER_RUNNER_WIN32_WINDOW", L"Haustelefon");
    if (existing != nullptr && !start_hidden) {
      // Auch aus dem Infobereich (versteckt) zurueckholen.
      ::ShowWindow(existing, SW_SHOW);
      if (::IsIconic(existing)) ::ShowWindow(existing, SW_RESTORE);
      ::SetForegroundWindow(existing);
    }
    return EXIT_SUCCESS;
  }

  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project, start_hidden);
  Win32Window::Point origin(80, 60);
  Win32Window::Size size(1120, 800);
  if (!window.Create(L"Haustelefon", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
