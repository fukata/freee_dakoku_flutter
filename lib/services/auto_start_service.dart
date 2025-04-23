import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:process_run/process_run.dart';
import 'package:path_provider/path_provider.dart';

/// Service for handling auto-start functionality across different platforms
class AutoStartService {
  /// Enables or disables auto-start based on the given state
  static Future<bool> setAutoStart(bool enable) async {
    try {
      if (Platform.isLinux) {
        return await _setLinuxAutoStart(enable);
      } else if (Platform.isWindows) {
        return await _setWindowsAutoStart(enable);
      } else if (Platform.isMacOS) {
        return await _setMacOSAutoStart(enable);
      }
      return false;
    } catch (e) {
      debugPrint('Error setting auto-start: $e');
      return false;
    }
  }

  /// Checks if auto-start is currently enabled
  static Future<bool> isAutoStartEnabled() async {
    try {
      if (Platform.isLinux) {
        return await _checkLinuxAutoStart();
      } else if (Platform.isWindows) {
        return await _checkWindowsAutoStart();
      } else if (Platform.isMacOS) {
        return await _checkMacOSAutoStart();
      }
      return false;
    } catch (e) {
      debugPrint('Error checking auto-start status: $e');
      return false;
    }
  }

  /// Linux implementation using .desktop files in ~/.config/autostart/
  static Future<bool> _setLinuxAutoStart(bool enable) async {
    final autostartDir = path.join(
      Platform.environment['HOME'] ?? '',
      '.config',
      'autostart',
    );
    final autostartFile = path.join(autostartDir, 'freee_dakoku.desktop');

    if (enable) {
      // Create autostart directory if it doesn't exist
      await Directory(autostartDir).create(recursive: true);

      // Get the path to the executable
      final executablePath = Platform.resolvedExecutable;
      final execDir = path.dirname(executablePath);

      // Create .desktop file
      final file = File(autostartFile);
      await file.writeAsString('''
[Desktop Entry]
Type=Application
Exec=$executablePath
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name=Freee打刻
Comment=Freee打刻アプリケーション
''');
      return true;
    } else {
      // Remove autostart file
      final file = File(autostartFile);
      if (await file.exists()) {
        await file.delete();
      }
      return true;
    }
  }

  /// Windows implementation using registry keys
  static Future<bool> _setWindowsAutoStart(bool enable) async {
    if (enable) {
      final executablePath = Platform.resolvedExecutable;

      // Use Windows registry to enable auto-start
      final shell = Shell();
      await shell.run('''
        REG ADD "HKEY_CURRENT_USER\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Run" /v "FreeeDAKOKU" /t REG_SZ /d "$executablePath" /f
      ''');
      return true;
    } else {
      // Remove registry key
      final shell = Shell();
      await shell.run('''
        REG DELETE "HKEY_CURRENT_USER\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Run" /v "FreeeDAKOKU" /f
      ''');
      return true;
    }
  }

  /// macOS implementation using launchctl / login items
  static Future<bool> _setMacOSAutoStart(bool enable) async {
    final appSupportDir = await getApplicationSupportDirectory();
    final plistDir = path.join(appSupportDir.path, 'LaunchAgents');
    final plistFile = path.join(plistDir, 'com.fukata.freee_dakoku.plist');

    if (enable) {
      // Create directory if it doesn't exist
      await Directory(plistDir).create(recursive: true);

      // Get the path to the executable
      final executablePath = Platform.resolvedExecutable;

      // Create plist file
      final file = File(plistFile);
      await file.writeAsString('''
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.fukata.freee_dakoku</string>
    <key>ProgramArguments</key>
    <array>
        <string>$executablePath</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
''');

      // Load the agent
      final shell = Shell();
      await shell.run('launchctl load -w $plistFile');
      return true;
    } else {
      // Unload and remove the agent
      final file = File(plistFile);
      if (await file.exists()) {
        final shell = Shell();
        await shell.run('launchctl unload -w $plistFile');
        await file.delete();
      }
      return true;
    }
  }

  /// Check if auto-start is enabled on Linux
  static Future<bool> _checkLinuxAutoStart() async {
    final autostartFile = path.join(
      Platform.environment['HOME'] ?? '',
      '.config',
      'autostart',
      'freee_dakoku.desktop',
    );

    final file = File(autostartFile);
    return await file.exists();
  }

  /// Check if auto-start is enabled on Windows
  static Future<bool> _checkWindowsAutoStart() async {
    try {
      final shell = Shell();
      final result = await shell.run(
        'REG QUERY "HKEY_CURRENT_USER\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Run" /v "FreeeDAKOKU"',
      );

      // If command succeeds, the key exists
      return result.outText.isNotEmpty;
    } catch (e) {
      return false; // Key doesn't exist
    }
  }

  /// Check if auto-start is enabled on macOS
  static Future<bool> _checkMacOSAutoStart() async {
    final appSupportDir = await getApplicationSupportDirectory();
    final plistFile = path.join(
      appSupportDir.path,
      'LaunchAgents',
      'com.fukata.freee_dakoku.plist',
    );

    final file = File(plistFile);
    return await file.exists();
  }
}
