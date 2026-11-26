import 'package:flutter/material.dart';

import 'splash_screen.dart';

import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'profile_gate.dart';
import 'profile_page.dart';

import 'custom_camera_screen.dart';
// import 'package:image_picker/image_picker.dart';
import 'services/document_import_service.dart';

import 'dart:io';

import 'services/pdf_import_service.dart';

import 'package:pdfrx/pdfrx.dart';

import 'models/document_page.dart';
import 'services/conversion_api_service.dart';

import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';

import 'services/history_service.dart';

// import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import 'services/profile_service.dart';
import 'models/evaluation_result.dart';
import 'services/evaluation_service.dart';
import 'screens/evaluation_result_screen.dart';
import 'widgets/app_pull_to_refresh.dart';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await pdfrxFlutterInitialize();

  final prefs = await SharedPreferences.getInstance();

  // Light is the default. Use Dark only if the user previously selected it.
  final savedTheme = prefs.getString('theme_mode');

  final initialThemeMode = savedTheme == 'dark'
      ? ThemeMode.dark
      : ThemeMode.light;

  runApp(
    InkoraApp(initialThemeMode: initialThemeMode),
  );
}

class InkoraApp extends StatefulWidget {
  const InkoraApp({
    super.key,
    required this.initialThemeMode,
  });

  final ThemeMode initialThemeMode;

  @override
  State<InkoraApp> createState() => _InkoraAppState();
}

class _InkoraAppState extends State<InkoraApp> {
  late ThemeMode _themeMode;

  late final ValueNotifier<ThemeMode> _themeModeNotifier;

  @override
  void initState() {
    super.initState();

    _themeMode = widget.initialThemeMode;
    _themeModeNotifier = ValueNotifier<ThemeMode>(_themeMode);
  }

  void changeTheme(ThemeMode mode) {
    if (mode == _themeMode) return;

    setState(() {
      _themeMode = mode;
    });

    // Notify every screen that listens to the theme preference.
    _themeModeNotifier.value = mode;

    // Persist the user's selection.
    SharedPreferences.getInstance().then((prefs) {
      return prefs.setString(
        'theme_mode',
        mode == ThemeMode.dark ? 'dark' : 'light',
      );
    });
  }

  @override
  void dispose() {
    _themeModeNotifier.dispose();
    super.dispose();
  }

  // Keep your existing makeTheme() method below this.

  ThemeData makeTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    const seed = Color(0xFF536DFE);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seed,
        brightness: brightness,
      ),
      scaffoldBackgroundColor: isDark
          ? const Color(0xFF10121A)
          : const Color(0xFFF7F8FC),
      appBarTheme: AppBarTheme(
        backgroundColor: isDark
            ? const Color(0xFF10121A)
            : const Color(0xFFF7F8FC),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: isDark ? const Color(0xFF1B1E29) : Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.07)
                : const Color(0xFFE9EBF3),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF20232F) : const Color(0xFFF3F5FA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: seed, width: 1.5),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    return MaterialApp(
      title: 'Inkora AI',
      debugShowCheckedModeBanner: false,
      theme: makeTheme(Brightness.light),
      darkTheme: makeTheme(Brightness.dark),
      themeMode: _themeMode,

      // Temporary OCR integration test route.
      home: InkoraSplashScreen(
        nextScreen: ProfileGate(
          authenticatedHome: InkoraShell(
            themeModeListenable: _themeModeNotifier,
            onThemeChanged: changeTheme,
          ),
        ),
      ),
    );
  }
}

class InkoraShell extends StatefulWidget {
  const InkoraShell({
    super.key,
    required this.themeModeListenable,
    required this.onThemeChanged,
  });

  final ValueListenable<ThemeMode> themeModeListenable;
  final ValueChanged<ThemeMode> onThemeChanged;

  @override
  State<InkoraShell> createState() => _InkoraShellState();
}

class _InkoraShellState extends State<InkoraShell> {
  int _selectedIndex = 0;
  bool _isExitDialogOpen = false;

  Future<void> _showExitConfirmation() async {
    if (_isExitDialogOpen) return;

    _isExitDialogOpen = true;

    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Exit Inkora AI?'),
          content: const Text('Are you sure you want to exit the application?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Exit'),
            ),
          ],
        );
      },
    );

    _isExitDialogOpen = false;

    if (shouldExit == true && mounted) {
      SystemNavigator.pop();
    }
  }

  void _goTo(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomePage(onNavigate: _goTo),
      const ConvertPage(),
      const EvaluatePage(),
      const HistoryPage(),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _showExitConfirmation();
      },
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 20,
          title: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF536DFE), Color(0xFF8B7CFF)],
                  ),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 23,
                ),
              ),
              const SizedBox(width: 10),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Inkora AI',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 19,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    'Write. Understand. Improve.',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w400),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Appearance',
              onPressed: () => _showAppearance(context),
              icon: const Icon(Icons.contrast_rounded),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: IconButton.filledTonal(
                tooltip: 'Profile and settings',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProfilePage(
                        themeModeListenable: widget.themeModeListenable,
                        onThemeChanged: widget.onThemeChanged,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.person_outline_rounded),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: IndexedStack(index: _selectedIndex, children: pages),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: _goTo,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.document_scanner_outlined),
              selectedIcon: Icon(Icons.document_scanner_rounded),
              label: 'Convert',
            ),
            NavigationDestination(
              icon: Icon(Icons.fact_check_outlined),
              selectedIcon: Icon(Icons.fact_check_rounded),
              label: 'Evaluate',
            ),
            NavigationDestination(
              icon: Icon(Icons.history_rounded),
              label: 'History',
            ),
          ],
        ),
      ),
    );
  }

  void _showAppearance(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Appearance',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),

              ValueListenableBuilder<ThemeMode>(
                valueListenable: widget.themeModeListenable,
                builder: (context, currentTheme, child) {
                  return RadioGroup<ThemeMode>(
                    groupValue: currentTheme,
                    onChanged: (mode) {
                      if (mode != null) {
                        widget.onThemeChanged(mode);
                        Navigator.pop(sheetContext);
                      }
                    },
                    child: const Column(
                      children: [
                        RadioListTile<ThemeMode>(
                          value: ThemeMode.light,
                          secondary: Icon(Icons.light_mode_outlined),
                          title: Text('Light mode'),
                        ),
                        RadioListTile<ThemeMode>(
                          value: ThemeMode.dark,
                          secondary: Icon(Icons.dark_mode_outlined),
                          title: Text('Dark mode'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

// HOME

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.onNavigate});

  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppPullToRefresh(
      onRefresh: () async {},
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          Text(
            'Your ideas,',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
            ),
          ),
          Text(
            'made intelligent.',
            style: theme.textTheme.headlineMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Turn handwritten pages into editable documents '
            'and make every answer count.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 24),

          // Hero card
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF4359E8),
                  Color(0xFF7867F8),
                  Color(0xFF9B80F8),
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome, size: 14, color: Colors.white),
                      SizedBox(width: 6),
                      Text(
                        'YOUR AI WORKSPACE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'From paper to\npossibility.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 29,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'One workspace for your notes and answers.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 22),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF4359E8),
                      ),
                      onPressed: () => onNavigate(1),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Convert notes'),
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                      onPressed: () => onNavigate(2),
                      icon: const Icon(Icons.fact_check_outlined),
                      label: const Text('Evaluate'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),
          const SectionHeading(
            title: 'What would you like to do?',
            subtitle: 'Choose your next task',
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: ActionCard(
                  icon: Icons.document_scanner_rounded,
                  title: 'Note converter',
                  description: 'Handwriting to editable text',
                  color: const Color(0xFF536DFE),
                  onTap: () => onNavigate(1),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ActionCard(
                  icon: Icons.fact_check_rounded,
                  title: 'Answer analyser',
                  description: 'Marks and useful feedback',
                  color: const Color(0xFF16A58A),
                  onTap: () => onNavigate(2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          SectionHeading(
            title: 'Recent activity',
            subtitle: 'Your latest work appears here',
            trailing: TextButton(
              onPressed: () => onNavigate(3),
              child: const Text('View all'),
            ),
          ),
          const SizedBox(height: 12),
          const EmptyActivityCard(),
          const SizedBox(height: 20),
          const Row(
            children: [
              Icon(Icons.shield_outlined, size: 17, color: Color(0xFF16A58A)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Your personal workspace, designed around your workflow.',
                  style: TextStyle(fontSize: 11),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// CONVERT

class ConvertPage extends StatefulWidget {
  const ConvertPage({super.key});

  @override
  State<ConvertPage> createState() => _ConvertPageState();
}

class _ConvertPageState extends State<ConvertPage> {
  final DocumentImportService _importService = DocumentImportService();
  final ConversionApiService _conversionService = ConversionApiService();

  String? _convertedWordPath;
  String? _convertedPdfPath;
  bool _isConverting = false;
  bool _isImporting = false;
  File? _selectedPdf;
  int? _pdfPageCount;
  bool _isLoadingPdf = false;

  final PdfImportService _pdfImportService = PdfImportService();
  final List<DocumentPage> _documentPages = [];

  Future<void> _chooseImages() async {
    if (_documentPages.length >= 100) {
      _showMessage('You can select up to 100 pages.');
      return;
    }

    await _runImport(() async {
      final availableSlots = 100 - _documentPages.length;

      final images = await _importService.pickImages(maxImages: availableSlots);

      if (!mounted || images.isEmpty) return;

      setState(() {
        for (final image in images) {
          _documentPages.add(
            DocumentPage(
              imagePath: image.path,
              pageNumber: _documentPages.length + 1,
              source: DocumentPageSource.gallery,
            ),
          );
        }
      });

      _showMessage('${images.length} image(s) added successfully.');
    });
  }

  Future<void> _capturePage() async {
    if (_documentPages.length >= 100) {
      _showMessage('You can select up to 100 pages.');
      return;
    }

    final capturedImage = await Navigator.of(context).push<XFile>(
      MaterialPageRoute(builder: (context) => const CustomCameraScreen()),
    );

    if (!mounted || capturedImage == null) return;

    setState(() {
      _documentPages.add(
        DocumentPage(
          imagePath: capturedImage.path,
          pageNumber: _documentPages.length + 1,
          source: DocumentPageSource.camera,
        ),
      );
    });
  }

  Future<void> _runImport(Future<void> Function() action) async {
    if (_isImporting) return;

    setState(() => _isImporting = true);

    try {
      await action();
    } catch (error) {
      if (mounted) {
        _showMessage('Could not import images: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
  }

  Future<void> _choosePdf() async {
    final renderedForThisImport = <File>[];

    try {
      if (_isLoadingPdf) return;

      final pdf = await _pdfImportService.pickPdf();

      if (!mounted || pdf == null) return;

      setState(() {
        _isLoadingPdf = true;
        _selectedPdf = pdf;
        _pdfPageCount = null;
      });

      final pageCount = await _pdfImportService.getPageCount(pdf);

      if (!mounted) return;

      final availableSlots = 100 - _documentPages.length;

      if (pageCount > availableSlots) {
        throw StateError(
          'This PDF has $pageCount pages, but only '
          '$availableSlots page slots are available. '
          'Remove some pages before importing this PDF.',
        );
      }

      setState(() {
        _pdfPageCount = pageCount;
      });

      for (var startPage = 0; startPage < pageCount; startPage += 4) {
        final files = await _pdfImportService.renderBatch(
          pdf,
          startPage: startPage,
          batchSize: 4,
        );

        renderedForThisImport.addAll(files);

        if (!mounted) {
          for (final file in renderedForThisImport) {
            if (await file.exists()) {
              await file.delete();
            }
          }
          return;
        }

        setState(() {
          for (final file in files) {
            _documentPages.add(
              DocumentPage(
                imagePath: file.path,
                pageNumber: _documentPages.length + 1,
                source: DocumentPageSource.pdf,
              ),
            );
          }
        });
      }

      if (!mounted) return;

      _showMessage('$pageCount PDF pages rendered successfully.');
    } catch (error) {
      // Roll back pages created by this PDF import.
      if (mounted && renderedForThisImport.isNotEmpty) {
        final paths = renderedForThisImport.map((file) => file.path).toSet();

        setState(() {
          _documentPages.removeWhere((page) => paths.contains(page.imagePath));

          for (var i = 0; i < _documentPages.length; i++) {
            final page = _documentPages[i];

            _documentPages[i] = DocumentPage(
              imagePath: page.imagePath,
              pageNumber: i + 1,
              source: page.source,
            );
          }
        });
      }

      for (final file in renderedForThisImport) {
        try {
          if (await file.exists()) {
            await file.delete();
          }
        } catch (_) {
          // Preserve the original import error.
        }
      }

      if (!mounted) return;

      _showMessage('Could not process PDF: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingPdf = false;
        });
      }
    }
  }

  Future<String> _requestDocumentName() async {
    String enteredName = '';

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          scrollable: true,
          title: const Text('Name your document'),
          content: TextFormField(
            initialValue: '',
            autofocus: false,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Untitled',
              labelText: 'Document name',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              enteredName = value;
            },
            onFieldSubmitted: (value) {
              Navigator.of(dialogContext).pop(value);
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(null);
              },
              child: const Text('Use Untitled'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(enteredName);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    final name = result?.trim() ?? '';

    return name.isEmpty ? 'Untitled' : name;
  }

  String _sanitizeDocumentName(String value) {
    var name = value.trim();

    // Remove an existing Word or PDF extension.
    name = name.replaceFirst(
      RegExp(r'\.(docx|pdf)$', caseSensitive: false),
      '',
    );

    // Replace characters that are unsafe in filenames.
    name = name.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_');

    name = name
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'[. ]+$'), '')
        .trim();

    if (name.isEmpty) {
      return 'Untitled';
    }

    if (name.length > 100) {
      name = name.substring(0, 100).trim();
    }

    return name.isEmpty ? 'Untitled' : name;
  }

  Future<void> _convertPages() async {
    if (_documentPages.isEmpty) {
      _showMessage('Please select at least one page.');
      return;
    }

    if (_isConverting) return;

    setState(() {
      _isConverting = true;
      _convertedWordPath = null;
      _convertedPdfPath = null;
    });

    try {
      final pages = _documentPages
          .map((page) => XFile(page.imagePath))
          .toList();

      // Step 1: Convert documents using the existing backend.
      final documents = await _conversionService.convertPages(pages);

      if (!mounted) return;

      // Step 2: Ask the student to name the document.
      final enteredName = await _requestDocumentName();

      if (!mounted) return;

      final documentName = _sanitizeDocumentName(enteredName);

      // Step 3: Rename both files locally.
      final wordFile = File(documents.wordPath);
      final pdfFile = File(documents.pdfPath);

      final renamedWord = await wordFile.rename(
        '${wordFile.parent.path}/$documentName.docx',
      );

      final renamedPdf = await pdfFile.rename(
        '${pdfFile.parent.path}/$documentName.pdf',
      );

      // Step 4: Save the renamed documents in history.
      try {
        await HistoryService.instance.saveConversion(
          title: documentName,
          pageCount: _documentPages.length,
          wordPath: renamedWord.path,
          pdfPath: renamedPdf.path,
        );
      } catch (historyError) {
        debugPrint('Could not save conversion history: $historyError');
      }

      if (!mounted) return;

      // Step 5: Update the conversion screen.
      setState(() {
        _convertedWordPath = renamedWord.path;
        _convertedPdfPath = renamedPdf.path;
      });

      _showMessage('$documentName saved successfully.');
    } catch (error) {
      if (!mounted) return;

      debugPrint('Inkora conversion error: $error');
      _showMessage('Conversion failed: $error');
    } finally {
      if (mounted) {
        setState(() => _isConverting = false);
      }
    }
  }

  Future<void> _downloadDocument(String sourcePath) async {
    try {
      final sourceFile = File(sourcePath);

      if (!await sourceFile.exists()) {
        _showMessage('The document could not be found. Please convert again.');
        return;
      }

      final fileName = sourceFile.uri.pathSegments.last;

      final savedPath = await FilePicker.saveFile(
        dialogTitle: 'Save your Inkora AI document',
        fileName: fileName,
        bytes: await sourceFile.readAsBytes(),
      );

      if (!mounted) return;

      if (savedPath != null) {
        _showMessage('Document saved successfully.');
      }
    } catch (error) {
      if (!mounted) return;

      debugPrint('Inkora document download error: $error');
      _showMessage('Could not save the document. Please try again.');
    }
  }

  Future<void> _shareDocument(String path) async {
    try {
      await SharePlus.instance.share(ShareParams(files: [XFile(path)]));
    } catch (error) {
      if (!mounted) return;
      _showMessage('Could not share document: $error');
    }
  }

  Future<void> _refreshConvertScreen() async {
    if (_isConverting || _isImporting || _isLoadingPdf) {
      _showMessage('Please wait for the current operation to finish.');
      return;
    }

    // Only remove temporary page images created from an imported PDF.
    final temporaryPdfPages = _documentPages
        .where((page) => page.source == DocumentPageSource.pdf)
        .map((page) => File(page.imagePath))
        .toList();

    setState(() {
      _documentPages.clear();

      _selectedPdf = null;
      _pdfPageCount = null;

      _convertedWordPath = null;
      _convertedPdfPath = null;
    });

    for (final file in temporaryPdfPages) {
      try {
        if (await file.exists()) {
          await file.delete();
        }
      } catch (error) {
        debugPrint('Could not remove temporary PDF page: $error');
      }
    }

    if (!mounted) return;
    _showMessage('Convert screen refreshed.');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _removeImage(int index) {
    if (index < 0 || index >= _documentPages.length) {
      return;
    }

    setState(() {
      _documentPages.removeAt(index);

      for (var i = 0; i < _documentPages.length; i++) {
        final page = _documentPages[i];

        _documentPages[i] = DocumentPage(
          imagePath: page.imagePath,
          pageNumber: i + 1,
          source: page.source,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppPullToRefresh(
      onRefresh: _refreshConvertScreen,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Note converter',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),
          const Text('Turn handwritten pages into editable digital documents.'),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.document_scanner_rounded,
                  size: 54,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 14),
                Text(
                  'Bring your notes to life',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Select handwritten pages or capture them '
                  'with your camera.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isImporting ? null : _chooseImages,
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: const Text('Choose images'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isImporting ? null : _capturePage,
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('Capture a page'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isLoadingPdf ? null : _choosePdf,
                    icon: const Icon(Icons.picture_as_pdf),
                    label: Text(
                      _isLoadingPdf ? 'Reading PDF...' : 'Import PDF',
                    ),
                  ),
                ),
                if (_selectedPdf != null)
                  Card(
                    child: ListTile(
                      leading: const Icon(
                        Icons.picture_as_pdf,
                        color: Colors.red,
                      ),
                      title: Text(
                        _selectedPdf!.path.split(Platform.pathSeparator).last,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text('${_pdfPageCount ?? 0} pages'),
                      trailing: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          setState(() {
                            _selectedPdf = null;
                            _pdfPageCount = null;
                          });
                        },
                      ),
                    ),
                  ),

                if (_isImporting) ...[
                  const SizedBox(height: 16),
                  const LinearProgressIndicator(),
                  const SizedBox(height: 8),
                  const Text('Opening image source...'),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Selected pages',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Chip(label: Text('${_documentPages.length} / 100')),
            ],
          ),
          const SizedBox(height: 8),
          if (_documentPages.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Center(
                  child: Text(
                    'Your selected pages will appear here.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            )
          else
            ...List.generate(_documentPages.length, (index) {
              final page = _documentPages[index];
              final fileName = page.imagePath
                  .split(Platform.pathSeparator)
                  .last;

              return Card(
                clipBehavior: Clip.antiAlias,
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(
                          File(page.imagePath),
                          width: 76,
                          height: 96,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 76,
                              height: 96,
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.broken_image_outlined,
                                size: 30,
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Page ${page.pageNumber}',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              fileName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Source: ${page.source.name}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Remove page',
                        onPressed: () => _removeImage(index),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                ),
              );
            }),

          const SizedBox(height: 24),

          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isConverting || _isLoadingPdf || _isImporting
                  ? null
                  : _convertPages,
              icon: _isConverting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome_rounded),
              label: Text(
                _isConverting
                    ? 'Converting handwritten pages...'
                    : 'Convert to Word & PDF',
              ),
            ),
          ),

          if (_isConverting) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
            const SizedBox(height: 8),
            const Text(
              'Recognising handwriting and preparing your documents. '
              'Please keep the app open.',
              textAlign: TextAlign.center,
            ),
          ],

          if (_convertedWordPath != null && _convertedPdfPath != null) ...[
            const SizedBox(height: 16),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your documents are ready',
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    const Text('Saved in Inkora AI app storage.'),
                    const SizedBox(height: 12),

                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () async {
                          final result = await OpenFilex.open(
                            _convertedWordPath!,
                          );

                          if (!context.mounted) return;

                          if (result.type != ResultType.done) {
                            _showMessage(
                              'Could not open the Word document. '
                              'Install a compatible document viewer.',
                            );
                          }
                        },
                        icon: const Icon(Icons.description_outlined),
                        label: const Text('Open Word document'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.tonalIcon(
                        onPressed: () => _shareDocument(_convertedWordPath!),
                        icon: const Icon(Icons.share_outlined),
                        label: const Text('Share Word File'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.tonalIcon(
                        onPressed: () => _downloadDocument(_convertedWordPath!),
                        icon: const Icon(Icons.download_rounded),
                        label: const Text('Download Word document'),
                      ),
                    ),

                    const SizedBox(height: 8),

                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final result = await OpenFilex.open(
                            _convertedPdfPath!,
                          );

                          if (!context.mounted) return;

                          if (result.type != ResultType.done) {
                            _showMessage(
                              'Could not open the PDF. '
                              'Install a compatible PDF viewer.',
                            );
                          }
                        },
                        icon: const Icon(Icons.picture_as_pdf_outlined),
                        label: const Text('Open PDF document'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.tonalIcon(
                        onPressed: () => _shareDocument(_convertedPdfPath!),
                        icon: const Icon(Icons.share_outlined),
                        label: const Text('Share PDF'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.tonalIcon(
                        onPressed: () => _downloadDocument(_convertedPdfPath!),
                        icon: const Icon(Icons.download_rounded),
                        label: const Text('Download PDF'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 12),

          const InfoBanner(
            text:
                'Handwriting recognition may contain errors. '
                'Always check the downloaded documents for accuracy.',
          ),
        ],
      ),
    );
  }
}

// EVALUATE

class EvaluatePage extends StatefulWidget {
  const EvaluatePage({super.key});

  @override
  State<EvaluatePage> createState() => _EvaluatePageState();
}

class _EvaluatePageState extends State<EvaluatePage> {
  final _questionController = TextEditingController();
  final _answerController = TextEditingController();
  final _marksController = TextEditingController(text: '10');
  final _degreeController = TextEditingController();

  final _importService = DocumentImportService();
  final _evaluationService = EvaluationService();
  bool _isLoadingProfile = true;
  String _level = 'University';
  String _questionMode = 'Typed';
  String _answerMode = 'Typed';

  XFile? _questionImage;
  List<XFile> _answerImages = [];

  bool _isEvaluating = false;

  @override
  void dispose() {
    _questionController.dispose();
    _answerController.dispose();
    _marksController.dispose();
    _degreeController.dispose();
    _evaluationService.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadProfileDegree();
  }

  Future<void> _loadProfileDegree() async {
    if (!mounted) return;

    setState(() {
      _isLoadingProfile = true;
    });

    try {
      final user = ProfileService.instance.currentUser;
      if (user == null) throw Exception('Please sign in again.');

      final document = await ProfileService.instance
          .profileChanges(user.uid)
          .first;

      final degree = document.data()?['degree'];

      if (!document.exists || degree is! String || degree.trim().isEmpty) {
        throw Exception('Degree not found in your profile.');
      }

      if (!mounted) return;

      setState(() {
        _degreeController.text = degree.trim();
        _isLoadingProfile = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoadingProfile = false;
      });

      _showError('Could not load profile degree: $e');
    }
  }

  Future<void> _pickQuestionImage() async {
    try {
      final images = await _importService.pickImages(maxImages: 1);

      if (!mounted || images.isEmpty) return;

      setState(() {
        _questionImage = images.first;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _pickAnswerImages() async {
    try {
      final images = await _importService.pickImages(maxImages: 100);

      if (!mounted || images.isEmpty) return;

      setState(() {
        _answerImages = images;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _resetForm() async {
    if (_isEvaluating) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _questionController.clear();
      _answerController.clear();
      _marksController.text = '10';

      _level = 'University';

      _questionMode = 'Typed';
      _answerMode = 'Typed';

      _questionImage = null;
      _answerImages = [];
    });

    // Reload the original degree saved in the user's profile.
    await _loadProfileDegree();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Evaluation form has been reset.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _evaluateAnswer() async {
    final marks = double.tryParse(_marksController.text.trim());

    final questionText = _questionController.text.trim();
    final answerText = _answerController.text.trim();
    final degree = _degreeController.text.trim();

    if (_isLoadingProfile || degree.isEmpty) {
      _showError('Please enter a valid degree or academic field.');
      return;
    }
    // Validate question.
    if (_questionMode == 'Typed' && questionText.isEmpty) {
      _showError('Please enter the question.');
      return;
    }

    if (_questionMode == 'Handwritten' && _questionImage == null) {
      _showError('Please upload the handwritten question.');
      return;
    }

    // Validate student answer.
    if (_answerMode == 'Typed' && answerText.isEmpty) {
      _showError('Please enter the student answer.');
      return;
    }

    if (_answerMode == 'Handwritten' && _answerImages.isEmpty) {
      _showError('Please upload the handwritten answer pages.');
      return;
    }

    if (marks == null || marks <= 0) {
      _showError('Please enter valid positive maximum marks.');
      return;
    }

    if (degree.isEmpty) {
      _showError('Please enter the degree or academic field.');
      return;
    }

    setState(() => _isEvaluating = true);

    String? savedPdfPath;

    try {
      // Send all evaluation data in one API request.
      final response = await _evaluationService.evaluate(
        questionText: _questionMode == 'Typed' ? questionText : null,
        questionImage: _questionMode == 'Handwritten' ? _questionImage : null,
        studentAnswerText: _answerMode == 'Typed' ? answerText : null,
        studentAnswerImages: _answerMode == 'Handwritten' ? _answerImages : [],
        totalMarks: marks,
        academicLevel: _level,
        degreeField: degree,
      );

      if (!mounted) return;

      // Save the generated PDF locally.
      final appDirectory = await getApplicationDocumentsDirectory();

      final evaluationDirectory = Directory('${appDirectory.path}/evaluations');

      if (!await evaluationDirectory.exists()) {
        await evaluationDirectory.create(recursive: true);
      }

      final timestamp = DateTime.now().microsecondsSinceEpoch;

      savedPdfPath = '${evaluationDirectory.path}/evaluation_$timestamp.pdf';

      final pdfFile = File(savedPdfPath);

      await pdfFile.writeAsBytes(response.pdfBytes, flush: true);

      // Generate a readable history title.
      final titleSource = _questionMode == 'Typed'
          ? questionText
          : 'Handwritten question';

      final title = titleSource.length > 55
          ? '${titleSource.substring(0, 55)}...'
          : titleSource;

      final result = EvaluationResult(
        title: title,
        totalMarks: response.totalMarks > 0 ? response.totalMarks : marks,
        marksAwarded: response.marksAwarded,
        feedbackSummary: response.feedbackSummary,
        scoreRationale: response.scoreRationale,
        pdfPath: savedPdfPath,
        createdAt: DateTime.now(),
      );

      // Save history only after successful PDF generation.
      try {
        await HistoryService.instance.saveEvaluation(
          title: title,
          pdfPath: savedPdfPath,
          score: response.marksAwarded,
          feedback: response.feedbackSummary,
        );
      } catch (e) {
        // Avoid leaving an untracked evaluation PDF behind.
        if (await pdfFile.exists()) {
          await pdfFile.delete();
        }
        rethrow;
      }

      if (!mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => EvaluationResultScreen(result: result),
        ),
      );
    } catch (e) {
      // Clean up a PDF if an error occurs after it was created.
      if (savedPdfPath != null) {
        final file = File(savedPdfPath);

        if (await file.exists()) {
          await file.delete();
        }
      }

      if (!mounted) return;

      _showError('Evaluation failed: $e');
    } finally {
      if (mounted) {
        setState(() => _isEvaluating = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildInputMode({
    required String value,
    required ValueChanged<String> onChanged,
  }) {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(
          value: 'Typed',
          label: Text('Typed'),
          icon: Icon(Icons.keyboard_outlined),
        ),
        ButtonSegment(
          value: 'Handwritten',
          label: Text('Handwritten'),
          icon: Icon(Icons.draw_outlined),
        ),
      ],
      selected: {value},
      onSelectionChanged: (values) {
        onChanged(values.first);
      },
    );
  }

  Widget _buildQuestionInput() {
    if (_questionMode == 'Typed') {
      return TextField(
        controller: _questionController,
        minLines: 2,
        maxLines: 4,
        decoration: const InputDecoration(
          hintText: 'Enter the question...',
          prefixIcon: Icon(Icons.help_outline_rounded),
          alignLabelWithHint: true,
        ),
      );
    }

    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(90)),
      onPressed: _isEvaluating ? null : _pickQuestionImage,
      icon: const Icon(Icons.add_photo_alternate_outlined),
      label: Text(
        _questionImage == null
            ? 'Upload one handwritten question image'
            : 'Question image selected',
      ),
    );
  }

  Widget _buildAnswerInput() {
    if (_answerMode == 'Typed') {
      return TextField(
        controller: _answerController,
        minLines: 6,
        maxLines: 10,
        decoration: const InputDecoration(
          hintText: 'Type the student answer here...',
          alignLabelWithHint: true,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(90),
          ),
          onPressed: _isEvaluating ? null : _pickAnswerImages,
          icon: const Icon(Icons.add_photo_alternate_outlined),
          label: const Text('Select handwritten answer pages'),
        ),
        if (_answerImages.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            '${_answerImages.length} page(s) selected',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          TextButton.icon(
            onPressed: _isEvaluating
                ? null
                : () {
                    setState(() => _answerImages = []);
                  },
            icon: const Icon(Icons.delete_outline),
            label: const Text('Remove selected pages'),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppPullToRefresh(
      onRefresh: _resetForm,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Answer analyser',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Review answers with structured marks and actionable feedback.',
          ),
          const SizedBox(height: 24),

          const SectionHeading(
            title: 'Evaluation details',
            subtitle: 'Set the criteria for your answer',
          ),
          const SizedBox(height: 18),

          const FieldLabel('Question input method'),
          const SizedBox(height: 8),
          _buildInputMode(
            value: _questionMode,
            onChanged: (value) {
              setState(() => _questionMode = value);
            },
          ),
          const SizedBox(height: 12),
          _buildQuestionInput(),

          const SizedBox(height: 20),
          const FieldLabel('Maximum marks'),
          const SizedBox(height: 8),
          TextField(
            controller: _marksController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              hintText: 'e.g. 10',
              prefixIcon: Icon(Icons.grade_outlined),
            ),
          ),

          const SizedBox(height: 18),
          const FieldLabel('Academic level'),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _level,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.school_outlined),
            ),
            items: const [
              DropdownMenuItem(value: 'School', child: Text('School')),
              DropdownMenuItem(value: 'University', child: Text('University')),
              DropdownMenuItem(
                value: 'Competitive exam',
                child: Text('Competitive exam'),
              ),
            ],
            onChanged: _isEvaluating
                ? null
                : (value) {
                    if (value != null) {
                      setState(() => _level = value);
                    }
                  },
          ),

          const FieldLabel('Degree / Academic field'),
          const SizedBox(height: 8),

          TextField(
            controller: _degreeController,
            enabled: !_isLoadingProfile && !_isEvaluating,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              hintText: 'Enter degree or academic field',
              prefixIcon: Icon(Icons.school_outlined),
              helperText:
                  'Auto-filled from your profile. '
                  'You can change it for this evaluation.',
            ),
          ),

          const SizedBox(height: 24),
          const SectionHeading(
            title: 'Student answer',
            subtitle: 'Choose how the answer will be submitted',
          ),
          const SizedBox(height: 16),

          _buildInputMode(
            value: _answerMode,
            onChanged: (value) {
              setState(() => _answerMode = value);
            },
          ),
          const SizedBox(height: 12),
          _buildAnswerInput(),

          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isEvaluating ? null : _evaluateAnswer,
              icon: _isEvaluating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.auto_awesome_rounded),
              label: Text(
                _isEvaluating ? 'Evaluating answer...' : 'Evaluate answer',
              ),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),

          const SizedBox(height: 16),
          const Text(
            'Evaluation results include suggested marks, '
            'strengths, missing concepts and improvement feedback.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, height: 1.6),
          ),
        ],
      ),
    );
  }
}

// HISTORY

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final TextEditingController _searchController = TextEditingController();

  String _filter = 'all';
  late Future<List<Map<String, Object?>>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  void _loadHistory() {
    _historyFuture = HistoryService.instance.getHistory(
      filter: _filter,
      searchQuery: _searchController.text,
    );
  }

  void _refreshHistory() {
    setState(_loadHistory);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatDate(Object? value) {
    if (value == null) return 'Date unavailable';

    final date = DateTime.tryParse(value.toString())?.toLocal();
    if (date == null) return 'Date unavailable';

    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';

    return '${date.day}/${date.month}/${date.year} · '
        '$hour:$minute $period';
  }

  Future<void> _openDocument(String? path) async {
    if (path == null || path.isEmpty) return;

    try {
      final file = File(path);

      if (!await file.exists()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('This file is no longer available on this device.'),
            ),
          );
        }
        return;
      }

      await OpenFilex.open(path);
    } catch (error) {
      debugPrint('History document open error: $error');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open this document.')),
        );
      }
    }
  }

  Future<void> _deleteRecord(int id, {required bool isEvaluation}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove history item?'),
        content: Text(
          isEvaluation
              ? 'This will permanently delete this evaluation record '
                    'and its generated PDF.'
              : 'This removes the conversion history record only. '
                    'Your Word and PDF files will remain untouched.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      if (isEvaluation) {
        await HistoryService.instance.deleteEvaluationItem(id);
      } else {
        await HistoryService.instance.deleteHistoryItem(id);
      }

      if (!mounted) return;

      _refreshHistory();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEvaluation
                ? 'Evaluation and PDF deleted.'
                : 'Conversion history record removed.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not delete record: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return AppPullToRefresh(
      onRefresh: () async {
        _refreshHistory();
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'History',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Your previous conversions and evaluations',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),

          TextField(
            controller: _searchController,
            onChanged: (_) => _refreshHistory(),
            decoration: InputDecoration(
              hintText: 'Search history...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      onPressed: () {
                        _searchController.clear();
                        _refreshHistory();
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const SizedBox(height: 16),

          Wrap(
            spacing: 8,
            children: [
              _filterChip('All', 'all'),
              _filterChip('Conversions', 'conversion'),
              _filterChip('Evaluations', 'evaluation'),
            ],
          ),
          const SizedBox(height: 20),

          FutureBuilder<List<Map<String, Object?>>>(
            future: _historyFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshot.hasError) {
                return _messageCard(
                  icon: Icons.error_outline_rounded,
                  title: 'Could not load history',
                  subtitle: 'Check your local database and try again.',
                );
              }

              final records = snapshot.data ?? [];

              if (records.isEmpty) {
                return _messageCard(
                  icon: Icons.history_rounded,
                  title: 'No history found',
                  subtitle: _searchController.text.isNotEmpty
                      ? 'Try a different search.'
                      : 'Your completed conversions will appear here.',
                );
              }

              return Column(
                children: records.map((record) {
                  final type = record['type']?.toString() ?? 'conversion';
                  final isConversion = type == 'conversion';
                  final id = record['id'] as int;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                backgroundColor: colors.primaryContainer,
                                child: Icon(
                                  isConversion
                                      ? Icons.description_outlined
                                      : Icons.grading_outlined,
                                  color: colors.onPrimaryContainer,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      record['title']?.toString() ??
                                          'Untitled record',
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      _formatDate(record['createdAt']),
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: colors.onSurfaceVariant,
                                          ),
                                    ),
                                    if (isConversion &&
                                        record['pageCount'] != null) ...[
                                      const SizedBox(height: 5),
                                      Text(
                                        '${record['pageCount']} page(s)',
                                        style: theme.textTheme.bodySmall,
                                      ),
                                    ],
                                    if (!isConversion &&
                                        record['score'] != null) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        'Marks awarded: ${record['score']}',
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                              color: colors.primary,
                                            ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'Remove history item',
                                onPressed: () => _deleteRecord(
                                  id,
                                  isEvaluation: !isConversion,
                                ),
                                icon: const Icon(Icons.delete_outline_rounded),
                              ),
                            ],
                          ),

                          if (isConversion) ...[
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () => _openDocument(
                                    record['wordPath']?.toString(),
                                  ),
                                  icon: const Icon(Icons.description_outlined),
                                  label: const Text('Open Word'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () => _openDocument(
                                    record['pdfPath']?.toString(),
                                  ),
                                  icon: const Icon(
                                    Icons.picture_as_pdf_outlined,
                                  ),
                                  label: const Text('Open PDF'),
                                ),
                              ],
                            ),
                          ],
                          if (!isConversion) ...[
                            const SizedBox(height: 14),
                            OutlinedButton.icon(
                              onPressed: () =>
                                  _openDocument(record['pdfPath']?.toString()),
                              icon: const Icon(Icons.picture_as_pdf_outlined),
                              label: const Text('Open Evaluation PDF'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),

          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.shield_outlined, color: colors.primary),
                      const SizedBox(width: 10),
                      Text(
                        'Privacy & Storage',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Your history records are stored locally on this '
                    'device and are not uploaded to Firebase.',
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Removing a conversion history record does not delete its '
                    'Word or PDF files. Removing an evaluation record also '
                    'deletes its generated PDF.',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String value) {
    return ChoiceChip(
      label: Text(label),
      selected: _filter == value,
      onSelected: (_) {
        setState(() {
          _filter = value;
          _loadHistory();
        });
      },
    );
  }

  Widget _messageCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
        child: Column(
          children: [
            Icon(icon, size: 42, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// REUSABLE UI COMPONENTS

class SectionHeading extends StatelessWidget {
  const SectionHeading({
    super.key,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (trailing case final Widget trailingWidget) trailingWidget,
      ],
    );
  }
}

class ActionCard extends StatelessWidget {
  const ActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                description,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.5,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EmptyActivityCard extends StatelessWidget {
  const EmptyActivityCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: Theme.of(context).colorScheme.primaryContainer,
              ),
              child: Icon(
                Icons.inbox_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'A fresh start',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'Your first project will show up here.',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class WorkflowStep extends StatelessWidget {
  const WorkflowStep({
    super.key,
    required this.number,
    required this.title,
    required this.description,
    required this.icon,
  });

  final String number;
  final String title;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$number  $title',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      height: 1.5,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class FieldLabel extends StatelessWidget {
  const FieldLabel(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
    );
  }
}

class InfoBanner extends StatelessWidget {
  const InfoBanner({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: theme.colorScheme.primary,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
