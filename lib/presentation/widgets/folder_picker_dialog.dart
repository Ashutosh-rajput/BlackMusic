import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';

class FolderPickerDialog extends StatefulWidget {
  final String? initialPath;

  const FolderPickerDialog({this.initialPath, super.key});

  @override
  State<FolderPickerDialog> createState() => _FolderPickerDialogState();
}

class _FolderPickerDialogState extends State<FolderPickerDialog> {
  late Directory _currentDir;

  @override
  void initState() {
    super.initState();
    String startPath = widget.initialPath ?? '/storage/emulated/0';
    Directory dir = Directory(startPath);
    if (!dir.existsSync()) {
      dir = Directory('/storage/emulated/0');
    }
    if (!dir.existsSync()) {
      dir = Directory.current;
    }
    _currentDir = dir;
  }

  Future<void> _pickNativeDirectory() async {
    try {
      final String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
      if (selectedDirectory != null && mounted) {
        Navigator.pop(context, selectedDirectory);
      }
    } catch (e) {
      debugPrint('Native folder picker fallback: $e');
    }
  }

  void _navigateTo(Directory dir) {
    if (dir.existsSync()) {
      setState(() {
        _currentDir = dir;
      });
    }
  }

  void _navigateUp() {
    final parent = _currentDir.parent;
    if (parent.path != _currentDir.path && parent.existsSync()) {
      setState(() {
        _currentDir = parent;
      });
    }
  }

  List<Directory> _getSubDirectories() {
    try {
      final entities = _currentDir.listSync(followLinks: false);
      final dirs = entities
          .whereType<Directory>()
          .where((d) => !d.path.split(RegExp(r'[/\\]')).last.startsWith('.'))
          .toList();
      dirs.sort((a, b) => a.path.toLowerCase().compareTo(b.path.toLowerCase()));
      return dirs;
    } catch (e) {
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final subDirs = _getSubDirectories();
    final canGoUp = _currentDir.parent.path != _currentDir.path;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      contentPadding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.folder_open_rounded, color: theme.colorScheme.primary, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Browse Folders',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ),
              IconButton.filledTonal(
                icon: const Icon(Icons.phonelink_setup_rounded, size: 20),
                tooltip: 'System Picker',
                onPressed: _pickNativeDirectory,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF262632) : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _currentDir.path,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 320,
        child: Column(
          children: [
            if (canGoUp)
              ListTile(
                dense: true,
                leading: const Icon(Icons.arrow_upward_rounded, color: Colors.amber),
                title: Text(
                  '.. (Parent Directory)',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                onTap: _navigateUp,
              ),
            Expanded(
              child: subDirs.isEmpty
                  ? Center(
                      child: Text(
                        'No subfolders inside this directory',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: subDirs.length,
                      itemBuilder: (ctx, idx) {
                        final dir = subDirs[idx];
                        final folderName = dir.path.split(RegExp(r'[/\\]')).last;
                        return ListTile(
                          dense: true,
                          leading: Icon(
                            Icons.folder_rounded,
                            color: theme.colorScheme.primary,
                            size: 24,
                          ),
                          title: Text(
                            folderName,
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                          onTap: () => _navigateTo(dir),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          icon: const Icon(Icons.check_circle_rounded, size: 18),
          label: const Text('Select This Folder'),
          onPressed: () => Navigator.pop(context, _currentDir.path),
        ),
      ],
    );
  }
}
