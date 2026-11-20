import 'package:flutter/material.dart';
import '../models/book.dart';
import '../services/book_parser.dart';
import '../services/focus_mode.dart';
import '../services/library_service.dart';
import '../services/reader_theme.dart';

class ReaderScreen extends StatefulWidget {
  final Book book;
  final LibraryService library;
  const ReaderScreen({super.key, required this.book, required this.library});

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  final _settings = ReaderSettings();
  final _focus = FocusMode();
  List<String> _pages = ['Loading…'];
  List<Chapter> _chapters = [];
  bool _loading = true;
  bool _focusOn = false;
  bool _controlsVisible = true;
  int _page = 0;
  late PageController _controller;

  @override
  void initState() {
    super.initState();
    _page = widget.book.lastPage;
    _controller = PageController(initialPage: _page);
    _load();
  }

  Future<void> _load() async {
    final parsed = await BookParser.parse(widget.book);
    if (!mounted) return;
    final pages = BookParser.paginate(
      parsed.text,
      BookParser.charsPerPageForFontSize(_settings.fontSize),
    );
    setState(() {
      _pages = pages;
      _chapters = parsed.chapters;
      _loading = false;
      widget.book.totalPages = pages.length;
      if (_page >= pages.length) _page = 0;
    });
    await widget.library.updateProgress(widget.book);
  }

  void _repaginate() {
    // Re-chunk text when font size changes; keep approximate position.
    _load();
  }

  Future<void> _onPageChanged(int index) async {
    _page = index;
    widget.book.lastPage = index;
    widget.book.progress =
        _pages.length <= 1 ? 1 : index / (_pages.length - 1);
    await widget.library.updateProgress(widget.book);
  }

  Future<void> _toggleFocus() async {
    if (_focusOn) {
      await _focus.exit();
      setState(() => _focusOn = false);
    } else {
      final messenger = ScaffoldMessenger.of(context);
      final granted = await _focus.isDndGranted();
      if (!granted && mounted) {
        final go = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Focus Mode needs Do Not Disturb access'),
            content: const Text(
              'To silence notifications while you read, Android needs you to allow '
              'Do Not Disturb access for this app. You can skip this and still '
              'read in full-screen — Focus Mode just will not silence notifications.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Skip for now'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Open settings'),
              ),
            ],
          ),
        );
        if (go == true) await _focus.requestDndAccess();
      }
      if (!mounted) return;
      await _focus.enter();
      if (!mounted) return;
      setState(() {
        _focusOn = true;
        _controlsVisible = false;
      });
      messenger.showSnackBar(
        const SnackBar(content: Text('Focus Mode on — notifications silenced. Tap the screen to show controls.')),
      );
    }
  }

  @override
  void dispose() {
    _focus.exit();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = _settings;
    return Scaffold(
      backgroundColor: settings.background,
      appBar: _controlsVisible
          ? AppBar(
              backgroundColor: settings.background,
              foregroundColor: settings.textColor,
              elevation: 0,
              title: Text(widget.book.title, style: const TextStyle(fontSize: 16)),
              actions: [
                IconButton(
                  icon: Icon(_focusOn ? Icons.do_not_disturb_on : Icons.do_not_disturb_off),
                  tooltip: 'Focus Mode',
                  onPressed: _toggleFocus,
                ),
                IconButton(icon: const Icon(Icons.settings), onPressed: _showSettings),
                IconButton(icon: const Icon(Icons.list), onPressed: _showToc),
              ],
            )
          : null,
      body: Stack(
        children: [
          GestureDetector(
            onTap: () => setState(() => _controlsVisible = !_controlsVisible),
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : PageView.builder(
                    controller: _controller,
                    itemCount: _pages.length,
                    onPageChanged: _onPageChanged,
                    itemBuilder: (_, i) => SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 72),
                      child: Text(
                        _pages[i],
                        style: TextStyle(
                          fontFamily: settings.theme.fontFamily,
                          fontSize: settings.fontSize,
                          height: settings.lineHeight,
                          color: settings.textColor,
                        ),
                      ),
                    ),
                  ),
          ),
          // Brightness dim overlay (does not block taps: IgnorePointer).
          if (settings.brightnessDim > 0)
            IgnorePointer(
              child: Container(color: Colors.black.withValues(alpha: settings.brightnessDim)),
            ),
          if (_controlsVisible && !_loading)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                color: settings.background,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.bookmark_border),
                          color: settings.textColor,
                          tooltip: 'Bookmark this page',
                          onPressed: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            await widget.library.toggleBookmark(widget.book, _page);
                            if (!mounted) return;
                            messenger.showSnackBar(
                              SnackBar(content: Text('Bookmark ${_page + 1} saved')),
                            );
                            setState(() {});
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.highlight),
                          color: settings.textColor,
                          tooltip: 'Highlight this page',
                          onPressed: () async {
                            final snippet = _pages[_page].length > 120
                                ? '${_pages[_page].substring(0, 120)}…'
                                : _pages[_page];
                            final messenger = ScaffoldMessenger.of(context);
                            await widget.library.addHighlight(widget.book, _page, snippet);
                            if (!mounted) return;
                            messenger.showSnackBar(
                              const SnackBar(content: Text('Highlight saved')),
                            );
                            setState(() {});
                          },
                        ),
                        const Spacer(),
                        Text(
                          'Page ${_page + 1} of ${_pages.length}',
                          style: TextStyle(color: settings.textColor),
                        ),
                        const Spacer(),
                        Text(
                          '${(widget.book.progress * 100).round()}%',
                          style: TextStyle(color: settings.textColor),
                        ),
                      ],
                    ),
                    if (widget.book.bookmarks.isNotEmpty)
                      Text(
                        'Bookmarks: ${widget.book.bookmarks.map((p) => p + 1).join(', ')}',
                        style: TextStyle(color: settings.textColor, fontSize: 12),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _showSettings() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Page style', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: PageTheme.values.map((t) {
                  return ChoiceChip(
                    label: Text(t.label),
                    selected: _settings.theme == t,
                    onSelected: (_) {
                      setSheetState(() => _settings.theme = t);
                      setState(() {});
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              Text(_settings.theme.description),
              SwitchListTile(
                title: const Text('Night mode'),
                value: _settings.nightMode,
                onChanged: (v) {
                  setSheetState(() => _settings.nightMode = v);
                  setState(() {});
                },
              ),
              Text('Font size: ${_settings.fontSize.round()}'),
              Slider(
                min: 14,
                max: 26,
                divisions: 12,
                value: _settings.fontSize,
                onChanged: (v) {
                  setSheetState(() => _settings.fontSize = v);
                  setState(() {});
                },
                onChangeEnd: (_) => _repaginate(),
              ),
              Text('Brightness dim: ${(_settings.brightnessDim * 100).round()}%'),
              Slider(
                min: 0,
                max: 0.5,
                value: _settings.brightnessDim,
                onChanged: (v) {
                  setSheetState(() => _settings.brightnessDim = v);
                  setState(() {});
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showToc() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (_) => ListView(
        children: [
          const ListTile(title: Text('Contents', style: TextStyle(fontWeight: FontWeight.bold))),
          ..._chapters.map((ch) {
            final page = (ch.startChar / BookParser.charsPerPageForFontSize(_settings.fontSize)).floor();
            return ListTile(
              title: Text(ch.title),
              subtitle: Text('Page ${page + 1}'),
              onTap: () {
                Navigator.pop(context);
                final target = page.clamp(0, _pages.length - 1);
                _controller.jumpToPage(target);
              },
            );
          }),
          if (widget.book.highlights.isNotEmpty) ...[
            const ListTile(title: Text('Highlights', style: TextStyle(fontWeight: FontWeight.bold))),
            ...widget.book.highlights.map((h) => ListTile(
                  title: Text(h.snippet, maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: Text('Page ${h.page + 1}'),
                  onTap: () {
                    Navigator.pop(context);
                    _controller.jumpToPage(h.page.clamp(0, _pages.length - 1));
                  },
                )),
          ],
        ],
      ),
    );
  }
}
