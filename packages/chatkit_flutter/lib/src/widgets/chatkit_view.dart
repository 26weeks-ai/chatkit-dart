import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:chatkit_core/chatkit_core.dart';
import 'package:collection/collection.dart';
import 'package:file_picker/file_picker.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';
import 'package:mime/mime.dart';
import 'package:share_plus/share_plus.dart';

import '../localization/localizations.dart';
import '../widgets/widget_renderer.dart';
import '../theme/tokens.dart';

class ChatKitView extends StatefulWidget {
  const ChatKitView({
    super.key,
    required this.controller,
  });

  final ChatKitController controller;

  @override
  State<ChatKitView> createState() => _ChatKitViewState();
}

class _ChatKitViewState extends State<ChatKitView> with WidgetsBindingObserver {
  final ScrollController _scrollController = ScrollController();
  late final TextEditingController _composerController;
  late final FocusNode _composerFocusNode;
  StreamSubscription<ChatKitEvent>? _subscription;

  List<ThreadItem> _items = const [];
  Thread? _thread;
  bool _isStreaming = false;
  bool _isUploading = false;
  List<ChatKitAttachment> _attachments = const [];
  List<_PendingUpload> _pendingUploads = const [];
  List<Entity> _selectedTags = const [];
  String? _selectedModelId;
  String? _selectedToolId;
  bool _composerEnabled = true;
  String? _composerDisabledReason;
  DateTime? _composerRetryAt;
  Timer? _composerRetryTicker;
  List<_BannerMessage> _banners = const [];
  bool _isDropTargetActive = false;
  int _dropDepth = 0;
  final Map<String, Map<String, String>> _dynamicLocalizationBundles = {};
  final Set<String> _loadingLocales = {};
  bool _suppressSnackbars = false;

  bool _historyOpen = false;
  final Map<_HistorySection, _HistorySectionState> _historySections = {
    for (final section in _HistorySection.values)
      section: const _HistorySectionState(),
  };
  _HistorySection _activeHistorySection = _HistorySection.recent;
  String _historySearchQuery = '';
  Timer? _historySearchDebounce;
  late final TextEditingController _historySearchController;
  final ScrollController _historyScrollController = ScrollController();
  int _historyRequestId = 0;
  bool _authExpired = false;
  final LayerLink _composerFieldLink = LayerLink();
  OverlayEntry? _tagSuggestionOverlay;
  List<Entity> _tagSuggestions = const [];
  bool _tagSuggestionVisible = false;
  bool _tagSuggestionLoading = false;
  int _tagSuggestionIndex = 0;
  int? _tagTriggerIndex;
  String _tagQuery = '';
  Timer? _tagSearchDebounce;
  final Map<String, FocusNode> _tagFocusNodes = {};

  ChatKitController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final composer = controller.composerState;
    _composerController = TextEditingController(text: composer.text);
    _historySearchController = TextEditingController(text: _historySearchQuery);
    _composerFocusNode = FocusNode(
      debugLabel: 'chatkit.composer',
      onKeyEvent: _handleComposerKeyEvent,
    );
    _composerFocusNode.addListener(_handleComposerFocusChange);
    _attachments = composer.attachments;
    _selectedTags = List<Entity>.from(composer.tags);
    _selectedModelId = composer.selectedModelId;
    _selectedToolId = composer.selectedToolId;
    _syncTagFocusNodes();
    _thread = controller.activeThread;
    _items = controller.threadItems;
    _subscription = controller.events.listen(_handleEvent);
    _historyScrollController.addListener(_handleHistoryScroll);
    if (controller.currentThreadId == null &&
        controller.options.initialThread != null) {
      unawaited(controller.setThreadId(controller.options.initialThread));
    }
    if (_historyEnabled) {
      _refreshHistory();
    }
    _ensureLocaleBundle();
  }

  @override
  void didUpdateWidget(covariant ChatKitView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _ensureLocaleBundle();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subscription?.cancel();
    _tagSearchDebounce?.cancel();
    _historySearchDebounce?.cancel();
    _composerRetryTicker?.cancel();
    _removeTagSuggestionOverlay();
    for (final node in _tagFocusNodes.values) {
      node.dispose();
    }
    _composerFocusNode.removeListener(_handleComposerFocusChange);
    _composerController.dispose();
    _historyScrollController.removeListener(_handleHistoryScroll);
    _historySearchController.dispose();
    _composerFocusNode.dispose();
    _scrollController.dispose();
    _historyScrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    if (!_composerFocusNode.hasFocus) {
      return;
    }
    _ensureComposerVisible();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.resumed:
        controller.handleAppForegrounded();
        _ensureComposerVisible();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        controller.handleAppBackgrounded();
        break;
      case AppLifecycleState.detached:
        controller.handleAppBackgrounded();
        break;
    }
  }

  bool get _historyEnabled => controller.options.history?.enabled ?? false;

  bool get _canAddEntities => controller.options.entities?.onTagSearch != null;

  bool get _attachmentsEnabled =>
      controller.options.composer?.attachments?.enabled == true;

  ChatKitLocalizations get _localizations => ChatKitLocalizations(
        locale: controller.options.locale,
        overrides: controller.options.localizationOverrides,
        bundles: {
          if (controller.options.localization != null)
            ...controller.options.localization!.bundles,
          ..._dynamicLocalizationBundles,
        },
        defaultLocale: controller.options.localization?.defaultLocale,
        pluralResolver: controller.options.localization?.pluralResolver,
      );

  void _ensureLocaleBundle() {
    final localization = controller.options.localization;
    final loader = localization?.loader;
    final locale = controller.options.locale;
    if (loader == null || locale == null || locale.isEmpty) {
      return;
    }
    final canonical = ChatKitLocalizations.canonicalize(locale);
    if (_dynamicLocalizationBundles.containsKey(canonical) ||
        localization!.bundles.containsKey(canonical) ||
        _loadingLocales.contains(canonical)) {
      return;
    }
    _loadingLocales.add(canonical);
    Future.microtask(() async {
      try {
        final bundle = await loader(canonical);
        if (!mounted) return;
        if (bundle.isNotEmpty) {
          setState(() {
            _dynamicLocalizationBundles[canonical] =
                Map<String, String>.unmodifiable(bundle);
          });
        }
      } catch (error) {
        if (mounted) {
          debugPrint(
            'ChatKit: failed to load localization bundle for $canonical: $error',
          );
        }
      } finally {
        _loadingLocales.remove(canonical);
      }
    });
  }

  _LayoutSize _layoutSizeOf(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final breakpoints = controller.options.resolvedTheme?.breakpoints;
    final compactMax = breakpoints?.compact ?? 640;
    final mediumMax = breakpoints?.medium ?? 1024;
    if (width <= compactMax) {
      return _LayoutSize.compact;
    }
    if (width <= mediumMax) {
      return _LayoutSize.medium;
    }
    return _LayoutSize.expanded;
  }

  void _handleEvent(ChatKitEvent event) {
    if (!mounted) return;
    _ensureLocaleBundle();
    if (event is ChatKitShareEvent) {
      unawaited(
        _handleShareEvent(
          threadId: event.threadId,
          itemId: event.itemId,
          content: event.content,
        ),
      );
      return;
    }
    if (event is ChatKitComposerAvailabilityEvent) {
      _applyComposerAvailability(event);
      return;
    }
    if (event is ChatKitNoticeEvent) {
      _enqueueBanner(event);
      return;
    }
    var hideSuggestions = false;
    setState(() {
      switch (event) {
        case ChatKitThreadChangeEvent(:final threadId):
          _thread = controller.activeThread;
          _items = controller.threadItems;
          if (threadId == null) {
            _composerController.clear();
            _attachments = const [];
          }
          _scheduleScrollToBottom();
          break;
        case ChatKitThreadEvent(:final streamEvent):
          _handleThreadEvent(streamEvent);
          break;
        case ChatKitResponseStartEvent():
          _isStreaming = true;
          break;
        case ChatKitResponseEndEvent():
          _isStreaming = false;
          _scheduleScrollToBottom();
          break;
        case ChatKitErrorEvent(:final error):
          if (error != null && context.mounted) {
            final messenger = ScaffoldMessenger.maybeOf(context);
            if (!_suppressSnackbars && messenger != null) {
              messenger.showSnackBar(
                SnackBar(content: Text(error)),
              );
            }
          }
          break;
        case ChatKitLogEvent():
          break;
        case ChatKitComposerUpdatedEvent(:final state):
          if (_composerController.text != state.text) {
            _composerController.value = TextEditingValue(
              text: state.text,
              selection: TextSelection.collapsed(offset: state.text.length),
            );
          }
          _attachments = state.attachments;
          _selectedTags = List<Entity>.from(state.tags);
          _selectedModelId = state.selectedModelId;
          _selectedToolId = state.selectedToolId;
          _syncTagFocusNodes();
          hideSuggestions = true;
          break;
        case ChatKitAuthExpiredEvent():
          _authExpired = true;
          break;
        case ChatKitComposerFocusEvent():
          _composerFocusNode.requestFocus();
          break;
        default:
          break;
      }
    });
    if (hideSuggestions) {
      _hideTagSuggestions();
    }
  }

  void _syncTagFocusNodes() {
    final ids = _selectedTags.map((tag) => tag.id).toSet();
    final toRemove =
        _tagFocusNodes.keys.where((id) => !ids.contains(id)).toList();
    for (final id in toRemove) {
      _tagFocusNodes.remove(id)?.dispose();
    }
    for (final tag in _selectedTags) {
      final node = _tagFocusNodes.putIfAbsent(
        tag.id,
        () => FocusNode(debugLabel: 'chatkit.tag.${tag.id}'),
      );
      node.onKeyEvent = (focusNode, event) => _handleTagChipKey(tag, event);
    }
  }

  void _handleThreadEvent(ThreadStreamEvent event) {
    switch (event) {
      case ThreadCreatedEvent(:final thread):
        _thread = thread;
        _items = controller.threadItems;
        _scheduleScrollToBottom();
        break;
      case ThreadItemAddedEvent(:final item):
        _removePendingPlaceholderFor(item);
        _upsertItem(item);
        _scheduleScrollToBottom();
        break;
      case ThreadItemDoneEvent(:final item):
        _upsertItem(item);
        _scheduleScrollToBottom();
        break;
      case ThreadItemUpdatedEvent(:final itemId):
        final updated = controller.threadItemById(itemId);
        if (updated != null) {
          _upsertItem(updated);
        }
        break;
      case ThreadItemReplacedEvent(:final item):
        _upsertItem(item);
        break;
      case ThreadItemRemovedEvent(:final itemId):
        _items = _items.where((element) => element.id != itemId).toList();
        break;
      case ThreadUpdatedEvent(:final thread):
        _thread = thread;
        break;
      case UnknownStreamEvent():
        break;
      case ProgressUpdateEvent(:final text):
        if (context.mounted) {
          final messenger = ScaffoldMessenger.maybeOf(context);
          if (!_suppressSnackbars && messenger != null) {
            messenger.showSnackBar(
              SnackBar(content: Text(text)),
            );
          }
        }
        break;
      case ErrorEvent(:final message):
        if (message != null && context.mounted) {
          final messenger = ScaffoldMessenger.maybeOf(context);
          if (!_suppressSnackbars && messenger != null) {
            messenger.showSnackBar(
              SnackBar(content: Text(message)),
            );
          }
        }
        break;
      case NoticeEvent():
        break;
    }

    if (_historyEnabled &&
        (event is ThreadCreatedEvent || event is ThreadUpdatedEvent)) {
      _refreshHistory();
    }
  }

  void _handleComposerChanged(String value) {
    controller.setComposerValue(text: value, tags: _selectedTags);
    _updateTagAutocomplete();
  }

  void _removePendingPlaceholderFor(ThreadItem item) {
    if (item.metadata['pending'] == true || !_isUserAuthoredItem(item)) {
      return;
    }
    final pendingIndex = _pendingPlaceholderIndex(item);
    if (pendingIndex != null) {
      final updated = [..._items]..removeAt(pendingIndex);
      _items = updated;
      return;
    }
    final fallbackIndex = _items.indexWhere(
      (entry) =>
          entry.metadata['pending'] == true &&
          entry.threadId == item.threadId,
    );
    if (fallbackIndex != -1) {
      final updated = [..._items]..removeAt(fallbackIndex);
      _items = updated;
    }
  }

  int? _pendingPlaceholderIndex(ThreadItem item) {
    if (_items.isEmpty) {
      return null;
    }
    const equality = DeepCollectionEquality();
    final attachmentSignature = _attachmentSignature(item);
    for (var index = 0; index < _items.length; index++) {
      final candidate = _items[index];
      if (candidate.metadata['pending'] == true &&
          candidate.threadId == item.threadId &&
          equality.equals(candidate.content, item.content) &&
          equality.equals(
            _attachmentSignature(candidate),
            attachmentSignature,
          )) {
        return index;
      }
    }
    return null;
  }

  List<Map<String, Object?>> _attachmentSignature(ThreadItem item) {
    if (item.attachments.isEmpty) {
      return const [];
    }
    return item.attachments
        .map((attachment) => attachment.toJson())
        .toList(growable: false);
  }

  bool _isUserAuthoredItem(ThreadItem item) {
    final type = item.type.toLowerCase();
    if (type == 'user_message') {
      return true;
    }
    final role = item.role?.toLowerCase();
    if (role == 'user') {
      return true;
    }
    for (final entry in item.content) {
      final contentType = (entry['type'] as String?)?.toLowerCase();
      if (contentType != null && contentType.startsWith('input_')) {
        return true;
      }
    }
    return false;
  }

  void _handleComposerFocusChange() {
    if (!_composerFocusNode.hasFocus) {
      _hideTagSuggestions();
      return;
    }
    _ensureComposerVisible();
  }

  KeyEventResult _handleComposerKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (_tagSuggestionVisible) {
      if (key == LogicalKeyboardKey.arrowDown ||
          key == LogicalKeyboardKey.arrowUp) {
        final count = _tagSuggestions.length;
        if (count == 0) {
          return KeyEventResult.handled;
        }
        setState(() {
          if (key == LogicalKeyboardKey.arrowDown) {
            _tagSuggestionIndex =
                (_tagSuggestionIndex + 1) % _tagSuggestions.length;
          } else {
            _tagSuggestionIndex =
                (_tagSuggestionIndex - 1 + _tagSuggestions.length) %
                    _tagSuggestions.length;
          }
        });
        _markTagOverlayNeedsBuild();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.enter ||
          key == LogicalKeyboardKey.numpadEnter ||
          key == LogicalKeyboardKey.tab) {
        if (_tagSuggestions.isNotEmpty) {
          _applyTagSuggestion(
            _tagSuggestions[
                _tagSuggestionIndex.clamp(0, _tagSuggestions.length - 1)],
          );
        } else {
          _hideTagSuggestions();
        }
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.escape) {
        _hideTagSuggestions();
        return KeyEventResult.handled;
      }
    }

    final selection = _composerController.selection;
    final atStart =
        selection.isValid && selection.isCollapsed && selection.baseOffset == 0;
    if (_selectedTags.isNotEmpty &&
        atStart &&
        (key == LogicalKeyboardKey.backspace ||
            key == LogicalKeyboardKey.arrowLeft)) {
      _focusTagChipAt(_selectedTags.length - 1);
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.home ||
        key == LogicalKeyboardKey.end) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _updateTagAutocomplete();
        }
      });
    }

    return KeyEventResult.ignored;
  }

  KeyEventResult _handleTagChipKey(Entity entity, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    final index = _selectedTags.indexWhere((tag) => tag.id == entity.id);
    if (index == -1) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final keysPressed = HardwareKeyboard.instance.logicalKeysPressed;
    final altPressed = keysPressed.contains(LogicalKeyboardKey.altLeft) ||
        keysPressed.contains(LogicalKeyboardKey.altRight);
    if (altPressed &&
        (key == LogicalKeyboardKey.arrowLeft ||
            key == LogicalKeyboardKey.arrowRight)) {
      _reorderTag(entity, key == LogicalKeyboardKey.arrowLeft ? -1 : 1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      if (index > 0) {
        _focusTagChipAt(index - 1);
      } else {
        _focusComposer(atEnd: false);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      if (index < _selectedTags.length - 1) {
        _focusTagChipAt(index + 1);
      } else {
        _focusComposer(atEnd: false);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.backspace ||
        key == LogicalKeyboardKey.delete) {
      final nextIndex = math.min(index, _selectedTags.length - 2);
      _removeTag(entity);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_selectedTags.isEmpty) {
          _focusComposer();
        } else if (nextIndex >= 0 && nextIndex < _selectedTags.length) {
          _focusTagChipAt(nextIndex);
        } else {
          _focusComposer();
        }
      });
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _focusTagChipAt(int index) {
    if (index < 0 || index >= _selectedTags.length) {
      _focusComposer(atEnd: index >= _selectedTags.length);
      return;
    }
    final tag = _selectedTags[index];
    final node = _tagFocusNodes[tag.id];
    node?.requestFocus();
  }

  String? _entityTooltip(Entity entity) {
    final data = entity.data;
    final tooltip = data['tooltip'];
    if (tooltip is String && tooltip.trim().isNotEmpty) {
      return tooltip.trim();
    }
    final description = data['description'];
    if (description is String && description.trim().isNotEmpty) {
      return description.trim();
    }
    return null;
  }

  Widget? _entityAvatar(Entity entity) {
    final icon = entity.icon;
    if (icon != null && icon.trim().isNotEmpty && icon.contains('://')) {
      return CircleAvatar(
        radius: 12,
        backgroundImage: CachedNetworkImageProvider(icon),
      );
    }
    return null;
  }

  void _focusComposer({bool atEnd = true}) {
    if (!_composerFocusNode.hasFocus) {
      _composerFocusNode.requestFocus();
    }
    final text = _composerController.text;
    final target = atEnd ? text.length : 0;
    final safeOffset = target.clamp(0, text.length).toInt();
    _composerController.selection = TextSelection.collapsed(offset: safeOffset);
    _ensureComposerVisible();
  }

  void _ensureComposerVisible() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_scrollController.hasClients) return;
      final mediaQuery = MediaQuery.maybeOf(context);
      if (mediaQuery == null) return;
      final bottomInset = mediaQuery.viewInsets.bottom;
      if (bottomInset <= 0 && !_composerFocusNode.hasFocus) {
        return;
      }
      final maxExtent = _scrollController.position.maxScrollExtent;
      if ((maxExtent - _scrollController.offset).abs() < 4) {
        return;
      }
      _scrollController.animateTo(
        maxExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _applyTagSuggestion(Entity entity) {
    final triggerIndex = _tagTriggerIndex;
    final selection = _composerController.selection;
    if (triggerIndex == null || !selection.isValid) {
      _hideTagSuggestions();
      return;
    }
    final end = selection.baseOffset;
    if (end < triggerIndex) {
      _hideTagSuggestions();
      return;
    }
    final text = _composerController.text;
    final newText = text.replaceRange(triggerIndex, end, '');
    _composerController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: triggerIndex),
    );
    if (!_selectedTags.any((tag) => tag.id == entity.id)) {
      setState(() {
        _selectedTags = [..._selectedTags, entity];
      });
      _syncTagFocusNodes();
    }
    controller.setComposerValue(text: newText, tags: _selectedTags);
    _hideTagSuggestions();
    _focusComposer(atEnd: false);
  }

  void _updateTagAutocomplete() {
    final searchFn = controller.options.entities?.onTagSearch;
    if (searchFn == null) {
      _hideTagSuggestions();
      return;
    }
    final selection = _composerController.selection;
    if (!selection.isValid || !selection.isCollapsed) {
      _hideTagSuggestions();
      return;
    }
    final cursor = selection.baseOffset;
    final text = _composerController.text;
    if (cursor <= 0 || text.isEmpty) {
      _hideTagSuggestions();
      return;
    }
    var index = cursor - 1;
    while (index >= 0) {
      final char = text[index];
      if (char == '@') {
        final boundaryOk = index == 0 ||
            RegExp(r'''[\s([{<>"'.!?:;-]''').hasMatch(text[index - 1]);
        if (!boundaryOk) {
          _hideTagSuggestions();
          return;
        }
        final query = text.substring(index + 1, cursor);
        if (query.isEmpty ||
            query.contains(RegExp(r'\s')) ||
            query.contains('\n')) {
          _hideTagSuggestions();
          return;
        }
        if (_tagSuggestionVisible &&
            !_tagSuggestionLoading &&
            _tagQuery == query) {
          return;
        }
        _tagSearchDebounce?.cancel();
        setState(() {
          _tagTriggerIndex = index;
          _tagQuery = query;
          _tagSuggestionIndex = 0;
          _tagSuggestions = const [];
          _tagSuggestionLoading = true;
          _tagSuggestionVisible = true;
        });
        _showTagSuggestions();
        _tagSearchDebounce = Timer(const Duration(milliseconds: 200), () async {
          List<Entity> results = const [];
          try {
            results = await Future<List<Entity>>.value(searchFn(query));
          } catch (_) {
            results = const [];
          }
          if (!mounted || _tagQuery != query) {
            return;
          }
          final selectedIds = _selectedTags.map((tag) => tag.id).toSet();
          results = results
              .where((entity) => !selectedIds.contains(entity.id))
              .toList();
          setState(() {
            _tagSuggestionLoading = false;
            _tagSuggestions = results;
            if (results.isEmpty) {
              _tagSuggestionIndex = 0;
            } else {
              _tagSuggestionIndex =
                  _tagSuggestionIndex.clamp(0, results.length - 1).toInt();
            }
          });
          _tagSearchDebounce = null;
          _markTagOverlayNeedsBuild();
        });
        _markTagOverlayNeedsBuild();
        return;
      }
      if (char == ' ' || char == '\n' || char == '\t') {
        break;
      }
      index -= 1;
    }
    _hideTagSuggestions();
  }

  void _showTagSuggestions() {
    if (_tagSuggestionOverlay != null) {
      _markTagOverlayNeedsBuild();
      return;
    }
    final overlay = Overlay.of(context);
    _tagSuggestionOverlay = OverlayEntry(
      builder: (context) => _buildTagSuggestionOverlay(),
    );
    overlay.insert(_tagSuggestionOverlay!);
  }

  void _hideTagSuggestions() {
    _tagSearchDebounce?.cancel();
    _tagSearchDebounce = null;
    if (!_tagSuggestionVisible &&
        !_tagSuggestionLoading &&
        _tagSuggestions.isEmpty) {
      _removeTagSuggestionOverlay();
      _tagTriggerIndex = null;
      _tagQuery = '';
      return;
    }
    if (!mounted) {
      _tagSuggestionVisible = false;
      _tagSuggestionLoading = false;
      _tagSuggestions = const [];
      _tagSuggestionIndex = 0;
      _tagTriggerIndex = null;
      _tagQuery = '';
      _removeTagSuggestionOverlay();
      return;
    }
    setState(() {
      _tagSuggestionVisible = false;
      _tagSuggestionLoading = false;
      _tagSuggestions = const [];
      _tagSuggestionIndex = 0;
      _tagTriggerIndex = null;
      _tagQuery = '';
    });
    _removeTagSuggestionOverlay();
  }

  void _removeTagSuggestionOverlay() {
    _tagSuggestionOverlay?.remove();
    _tagSuggestionOverlay = null;
  }

  void _markTagOverlayNeedsBuild() {
    _tagSuggestionOverlay?.markNeedsBuild();
  }

  Widget _buildTagSuggestionOverlay() {
    if (!_tagSuggestionVisible &&
        !_tagSuggestionLoading &&
        _tagSuggestions.isEmpty) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final l10n = _localizations;
    final suggestions = _tagSuggestions;
    final loading = _tagSuggestionLoading;

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _hideTagSuggestions,
          ),
        ),
        CompositedTransformFollower(
          link: _composerFieldLink,
          showWhenUnlinked: false,
          targetAnchor: Alignment.bottomLeft,
          followerAnchor: Alignment.topLeft,
          offset: const Offset(0, 6),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (loading)
                    const LinearProgressIndicator(
                      minHeight: 2,
                    ),
                  if (!loading && suggestions.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        l10n.t('tag_suggestions_empty'),
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  if (suggestions.isNotEmpty)
                    SizedBox(
                      width: double.infinity,
                      height: math.min(suggestions.length * 52.0, 240.0),
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: suggestions.length,
                        itemBuilder: (context, index) {
                          final suggestion = suggestions[index];
                          final selected = index == _tagSuggestionIndex;
                          final labelStyle =
                              theme.textTheme.bodyMedium?.copyWith(
                            color: selected
                                ? theme.colorScheme.primary
                                : theme.textTheme.bodyMedium?.color,
                          );
                          final description =
                              suggestion.data['description'] as String?;
                          return InkWell(
                            onTap: () => _applyTagSuggestion(suggestion),
                            child: Container(
                              color: selected
                                  ? theme.colorScheme.primary
                                      .withValues(alpha: 0.08)
                                  : Colors.transparent,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(suggestion.title, style: labelStyle),
                                  if (description != null &&
                                      description.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        description,
                                        style:
                                            theme.textTheme.bodySmall?.copyWith(
                                          color: selected
                                              ? theme.colorScheme.primary
                                                  .withValues(alpha: 0.8)
                                              : theme.textTheme.bodySmall?.color
                                                  ?.withValues(alpha: 0.7),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  if (loading && suggestions.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        l10n.t('tag_suggestions_loading'),
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleShareEvent({
    required String threadId,
    required String itemId,
    required List<Map<String, Object?>> content,
  }) async {
    if (!mounted) return;
    final shareText = _composeShareText(content);
    if (shareText.isEmpty) {
      return;
    }
    final l10n = _localizations;
    final shareActions = controller.options.threadItemActions?.shareActions;
    final targets = _resolveShareTargets(shareActions);
    if (targets.isEmpty) {
      return;
    }

    final result = await showModalBottomSheet<ShareTargetOption>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final theme = Theme.of(context);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.t('share_sheet_title'),
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                if (shareText.length > 200)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${shareText.substring(0, 200)}…',
                      style: theme.textTheme.bodySmall,
                    ),
                  )
                else
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      shareText,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                for (final target in targets)
                  ListTile(
                    leading: Icon(
                      _shareIconForTarget(target),
                      color: theme.colorScheme.primary,
                    ),
                    title: Text(_shareLabelForTarget(target, l10n)),
                    subtitle: target.description == null
                        ? null
                        : Text(
                            target.description!,
                            style: theme.textTheme.bodySmall,
                          ),
                    onTap: () => Navigator.pop(context, target),
                  ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(l10n.t('share_option_cancel')),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (result == null) {
      return;
    }
    await _performShareTarget(
      target: result,
      shareText: shareText,
      threadId: threadId,
      itemId: itemId,
      shareActions: shareActions,
      localizations: l10n,
    );
  }

  String _composeShareText(List<Map<String, Object?>> content) {
    final buffer = StringBuffer();
    for (final part in content) {
      final type = (part['type'] as String?)?.toLowerCase();
      if (type == null || type == 'text' || type == 'paragraph') {
        final text = part['text'] as String?;
        if (text != null && text.trim().isNotEmpty) {
          buffer.writeln(text.trim());
        }
      }
    }
    return buffer.toString().trim();
  }

  List<ShareTargetOption> _resolveShareTargets(
      ShareActionsOption? shareActions) {
    final targets = shareActions?.targets;
    if (targets != null && targets.isNotEmpty) {
      return targets;
    }
    return const [
      ShareTargetOption(
        id: 'copy',
        label: 'copy',
        type: ShareTargetType.copy,
      ),
      ShareTargetOption(
        id: 'system',
        label: 'system',
        type: ShareTargetType.system,
      ),
    ];
  }

  void _applyComposerAvailability(ChatKitComposerAvailabilityEvent event) {
    final retryAt =
        event.retryAfter == null ? null : DateTime.now().add(event.retryAfter!);
    _composerRetryTicker?.cancel();
    if (!mounted) return;
    setState(() {
      if (event.available) {
        _composerEnabled = true;
        _composerDisabledReason = null;
        _composerRetryAt = null;
        if (event.reason == 'auth') {
          _authExpired = false;
        }
      } else {
        _composerEnabled = false;
        _composerDisabledReason = event.reason;
        _composerRetryAt = retryAt;
        if (event.reason == 'auth') {
          _authExpired = true;
        }
        _isDropTargetActive = false;
        _dropDepth = 0;
      }
    });
    if (!event.available && retryAt != null) {
      _composerRetryTicker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) {
          _composerRetryTicker?.cancel();
          return;
        }
        if (_composerRetryAt == null ||
            DateTime.now().isAfter(_composerRetryAt!)) {
          _composerRetryTicker?.cancel();
        }
        setState(() {});
      });
    }
    if (event.available) {
      _removeBannersByCode('rate_limit');
    }
  }

  void _enqueueBanner(ChatKitNoticeEvent event) {
    if (!mounted) return;
    final l10n = _localizations;
    final code = event.code;
    String message = event.message.trim().isEmpty
        ? l10n.t('notice_generic_message')
        : event.message.trim();
    String? title = event.title;
    if (code == 'rate_limit') {
      title = l10n.t('notice_rate_limit_title');
      message = l10n.t('notice_rate_limit_message');
    } else if (title == null || title.isEmpty) {
      title = l10n.t('notice_generic_title');
    }
    final retryAt =
        event.retryAfter == null ? null : DateTime.now().add(event.retryAfter!);
    final banner = _BannerMessage(
      id: 'banner-${DateTime.now().microsecondsSinceEpoch}',
      message: message,
      title: title,
      level: event.level,
      code: code,
      retryAt: retryAt,
    );
    setState(() {
      final index = _banners.indexWhere((existing) {
        if (code != null && existing.code == code) {
          return true;
        }
        return existing.message == banner.message &&
            existing.level == banner.level;
      });
      if (index >= 0) {
        final existing = _banners[index];
        _banners = [
          ..._banners.sublist(0, index),
          existing.copyWith(
            message: banner.message,
            title: banner.title,
            retryAt: banner.retryAt,
            level: banner.level,
            code: banner.code ?? existing.code,
          ),
          ..._banners.sublist(index + 1),
        ];
      } else {
        _banners = [..._banners, banner];
      }
    });
  }

  void _removeBannersByCode(String code) {
    if (_banners.every((banner) => banner.code != code)) {
      return;
    }
    setState(() {
      _banners = _banners.where((banner) => banner.code != code).toList();
    });
  }

  void _dismissBanner(String id) {
    setState(() {
      _banners = _banners.where((banner) => banner.id != id).toList();
    });
  }

  String? _formatRetryCountdown(ChatKitLocalizations l10n) {
    final target = _composerRetryAt;
    if (target == null) {
      return null;
    }
    final remaining = target.difference(DateTime.now());
    if (remaining.isNegative) {
      return null;
    }
    final seconds = (remaining.inSeconds + 1).clamp(1, 600);
    return l10n.format('rate_limit_retry_in', {
      'seconds': seconds.toString(),
    });
  }

  String _shareLabelForTarget(
    ShareTargetOption target,
    ChatKitLocalizations l10n,
  ) {
    switch (target.type) {
      case ShareTargetType.copy:
        if (target.label.isNotEmpty && target.label != 'copy') {
          return target.label;
        }
        return l10n.t('share_option_copy');
      case ShareTargetType.system:
        if (target.label.isNotEmpty && target.label != 'system') {
          return target.label;
        }
        return l10n.t('share_option_system');
      case ShareTargetType.custom:
        return target.label;
    }
  }

  IconData _shareIconForTarget(ShareTargetOption target) {
    final iconName = target.icon?.toLowerCase();
    IconData? resolved;
    if (iconName != null && iconName.isNotEmpty) {
      resolved = switch (iconName) {
        'copy' => Icons.copy_all_outlined,
        'share' => Icons.ios_share,
        'link' => Icons.link,
        'mail' || 'email' => Icons.mail_outline,
        'message' || 'sms' => Icons.sms_outlined,
        'notes' => Icons.note_outlined,
        'slack' => Icons.chat_bubble_outline,
        'teams' => Icons.group_work_outlined,
        'download' => Icons.download_outlined,
        _ => null,
      };
    }
    if (resolved != null) {
      return resolved;
    }
    switch (target.type) {
      case ShareTargetType.copy:
        return Icons.copy_all_outlined;
      case ShareTargetType.system:
        return Icons.ios_share;
      case ShareTargetType.custom:
        return Icons.outbond;
    }
  }

  Future<void> _performShareTarget({
    required ShareTargetOption target,
    required String shareText,
    required String threadId,
    required String itemId,
    required ShareActionsOption? shareActions,
    required ChatKitLocalizations localizations,
  }) async {
    switch (target.type) {
      case ShareTargetType.copy:
        await Clipboard.setData(ClipboardData(text: shareText));
        _showShareToast(
          target.toast ??
              shareActions?.copyToast ??
              localizations.t('share_toast_copied'),
        );
        break;
      case ShareTargetType.system:
        await Share.share(shareText);
        _showShareToast(
          target.toast ??
              shareActions?.systemToast ??
              localizations.t('share_toast_shared'),
        );
        break;
      case ShareTargetType.custom:
        final handler = shareActions?.onSelectTarget;
        if (handler != null) {
          await Future.sync(
            () => handler(
              ShareTargetInvocation(
                targetId: target.id,
                itemId: itemId,
                threadId: threadId,
                text: shareText,
              ),
            ),
          );
        }
        final toast = target.toast ?? shareActions?.defaultToast;
        if (toast != null && toast.isNotEmpty) {
          _showShareToast(toast);
        }
        break;
    }
  }

  void _showShareToast(String? message) {
    if (!mounted || message == null || message.isEmpty) {
      return;
    }
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (!_suppressSnackbars && messenger != null) {
      messenger.showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  _HistorySectionState get _currentHistoryState =>
      _historySections[_activeHistorySection]!;

  List<ThreadMetadata> _filterHistoryThreads(List<ThreadMetadata> threads) {
    final query = _historySearchQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return List<ThreadMetadata>.from(threads);
    }
    return threads.where((thread) {
      final title = thread.title?.toLowerCase() ?? '';
      final metadata = thread.metadata.map(
        (key, value) => MapEntry(key.toLowerCase(), value),
      );
      final keywords = metadata['keywords'];
      final matchesKeywords = keywords is List
          ? keywords
              .whereType<String>()
              .any((keyword) => keyword.toLowerCase().contains(query))
          : false;
      return title.contains(query) ||
          thread.id.toLowerCase().contains(query) ||
          matchesKeywords;
    }).toList(growable: false);
  }

  bool _isThreadPinned(ThreadMetadata thread) {
    final value = thread.metadata['pinned'];
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      return normalized == 'true' || normalized == '1' || normalized == 'yes';
    }
    return false;
  }

  List<ThreadMetadata> _mergeHistoryThreads(
    List<ThreadMetadata> existing,
    List<ThreadMetadata> incoming,
  ) {
    if (existing.isEmpty) {
      return List<ThreadMetadata>.from(incoming);
    }
    final merged = List<ThreadMetadata>.from(existing);
    final indexById = <String, int>{};
    for (var i = 0; i < merged.length; i++) {
      indexById[merged[i].id] = i;
    }
    for (final thread in incoming) {
      final index = indexById[thread.id];
      if (index != null) {
        merged[index] = thread;
      } else {
        merged.add(thread);
      }
    }
    return merged;
  }

  Future<void> _refreshHistory({
    _HistorySection? section,
    bool reset = true,
  }) async {
    if (!_historyEnabled) {
      return;
    }
    final targetSection = section ?? _activeHistorySection;
    final stateBefore = _historySections[targetSection]!;
    final shouldReset = reset || !stateBefore.initialized;
    final pendingQuery = _historySearchQuery;
    final requestId = ++_historyRequestId;

    setState(() {
      final updated = stateBefore.copyWith(
        loadingInitial: shouldReset,
        loadingMore: !shouldReset,
        error: null,
        cursor: shouldReset ? null : stateBefore.cursor,
        hasMore: shouldReset ? false : stateBefore.hasMore,
        threads: shouldReset ? const [] : stateBefore.threads,
      );
      _historySections[targetSection] = updated;
    });

    try {
      final page = await controller.listThreads(
        limit: 20,
        after: shouldReset ? null : stateBefore.cursor,
        section: targetSection.metadataValue,
        query: pendingQuery.trim().isEmpty ? null : pendingQuery.trim(),
      );
      if (!mounted || requestId != _historyRequestId) {
        return;
      }
      final baseThreads =
          shouldReset ? const <ThreadMetadata>[] : stateBefore.threads;
      final merged = _mergeHistoryThreads(baseThreads, page.data);
      setState(() {
        _historySections[targetSection] =
            _historySections[targetSection]!.copyWith(
          threads: merged,
          cursor: page.after,
          hasMore: page.hasMore,
          loadingInitial: false,
          loadingMore: false,
          initialized: true,
        );
      });
    } catch (error) {
      if (!mounted || requestId != _historyRequestId) {
        return;
      }
      setState(() {
        _historySections[targetSection] =
            _historySections[targetSection]!.copyWith(
          error: error.toString(),
          loadingInitial: false,
          loadingMore: false,
          hasMore: shouldReset ? false : stateBefore.hasMore,
          cursor: shouldReset ? null : stateBefore.cursor,
          threads: shouldReset ? const [] : stateBefore.threads,
          initialized: true,
        );
      });
    }
  }

  void _toggleHistory() {
    if (!_historyEnabled) return;
    setState(() {
      _historyOpen = !_historyOpen;
    });
    if (_historyOpen) {
      final state = _currentHistoryState;
      if (!state.initialized) {
        _refreshHistory(section: _activeHistorySection, reset: true);
      }
    }
  }

  Future<void> _handleSelectThread(String? threadId) async {
    await controller.setThreadId(threadId);
    if (!mounted) return;
    if (threadId != null) {
      setState(() {
        _historyOpen = false;
      });
    }
  }

  Future<void> _loadMoreHistory() async {
    final state = _currentHistoryState;
    if (!state.hasMore || state.loadingMore || state.loadingInitial) {
      return;
    }
    await _refreshHistory(section: _activeHistorySection, reset: false);
  }

  void _handleHistorySectionChanged(_HistorySection section) {
    if (_activeHistorySection == section) {
      return;
    }
    setState(() {
      _activeHistorySection = section;
    });
    final state = _historySections[section]!;
    if (!state.initialized || _historySearchQuery.isNotEmpty) {
      _refreshHistory(section: section, reset: true);
    }
  }

  void _handleHistorySearchChanged(String value) {
    if (_historySearchQuery == value) {
      return;
    }
    setState(() {
      _historySearchQuery = value;
    });
    _historySearchDebounce?.cancel();
    _historySearchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      _refreshHistory(section: _activeHistorySection, reset: true);
    });
  }

  void _clearHistorySearch() {
    if (_historySearchQuery.isEmpty) {
      return;
    }
    _historySearchDebounce?.cancel();
    setState(() {
      _historySearchQuery = '';
      _historySearchController.value = const TextEditingValue(text: '');
    });
    _refreshHistory(section: _activeHistorySection, reset: true);
  }

  void _handleHistoryScroll() {
    if (!_historyScrollController.hasClients) {
      return;
    }
    final position = _historyScrollController.position;
    if (position.maxScrollExtent - position.pixels <= 120) {
      unawaited(_loadMoreHistory());
    }
  }

  Future<void> _handleDeleteThread(String threadId) async {
    await controller.deleteThread(threadId);
    if (!mounted) return;
    await _refreshHistory();
  }

  Future<void> _handleRenameThread(ThreadMetadata thread) async {
    final textController = TextEditingController(text: thread.title ?? '');
    final newTitle = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Rename conversation'),
          content: TextField(
            controller: textController,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Title'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(context, textController.text.trim()),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (newTitle != null && newTitle.isNotEmpty) {
      await this.controller.renameThread(thread.id, newTitle);
      if (mounted) {
        await _refreshHistory();
      }
    }
  }

  Future<void> _openEntityPicker() async {
    final entitiesOption = controller.options.entities;
    final searchFn = entitiesOption?.onTagSearch;
    if (searchFn == null) {
      return;
    }

    final l10n = _localizations;
    final searchController = TextEditingController();
    final searchFocusNode =
        FocusNode(debugLabel: 'chatkit.entityPicker.search');
    final resultsScrollController = ScrollController();
    Timer? searchDebounce;
    List<Entity> results = const [];
    bool loading = false;
    int highlightedIndex = -1;
    int searchRequestId = 0;

    Color _resolveColor(Object? value, Color fallback) {
      if (value is int) {
        return Color(value);
      }
      if (value is String) {
        final cleaned = value.trim().replaceFirst('#', '');
        if (cleaned.length == 6 || cleaned.length == 8) {
          final parsed = int.tryParse(cleaned, radix: 16);
          if (parsed != null) {
            if (cleaned.length == 6) {
              return Color(0xFF000000 | parsed);
            }
            return Color(parsed);
          }
        }
      }
      return fallback;
    }

    Widget? buildBadge(Entity entity, ThemeData theme) {
      final badge = entity.data['badge'];
      if (badge is String) {
        final text = badge.trim();
        if (text.isEmpty) return null;
        return _EntityBadge(
          label: text,
          background: theme.colorScheme.secondaryContainer,
          foreground: theme.colorScheme.onSecondaryContainer,
        );
      }
      if (badge is Map) {
        final label = (badge['label'] ?? badge['text']) as String?;
        if (label == null || label.trim().isEmpty) {
          return null;
        }
        final background = _resolveColor(
          badge['background'] ?? badge['color'],
          theme.colorScheme.secondaryContainer,
        );
        final foreground = _resolveColor(
          badge['foreground'] ?? badge['textColor'],
          theme.colorScheme.onSecondaryContainer,
        );
        return _EntityBadge(
          label: label.trim(),
          background: background,
          foreground: foreground,
        );
      }
      return null;
    }

    Widget buildAvatar(Entity entity, ThemeData theme) {
      final icon = entity.icon;
      if (icon != null && icon.trim().isNotEmpty && icon.contains('://')) {
        return CircleAvatar(
          radius: 18,
          backgroundImage: CachedNetworkImageProvider(icon),
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
        );
      }
      final label = entity.title.trim();
      final initial =
          label.isNotEmpty ? label.substring(0, 1).toUpperCase() : '@';
      return CircleAvatar(
        radius: 18,
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        child: Text(
          initial,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
      );
    }

    void ensureHighlightedVisible(int index) {
      if (!resultsScrollController.hasClients || index < 0) {
        return;
      }
      const itemExtent = 68.0;
      final targetOffset = index * itemExtent;
      final currentOffset = resultsScrollController.position.pixels;
      final viewportExtent = resultsScrollController.position.viewportDimension;
      final maxOffset = currentOffset + viewportExtent;
      if (targetOffset < currentOffset) {
        resultsScrollController.animateTo(
          targetOffset,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
      } else if (targetOffset + itemExtent > maxOffset) {
        final offset = targetOffset - (viewportExtent - itemExtent);
        resultsScrollController.animateTo(
          offset.clamp(
            0.0,
            resultsScrollController.position.maxScrollExtent,
          ),
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
      }
    }

    Future<void> runSearch(
      void Function(void Function()) setModalState,
    ) async {
      final query = searchController.text.trim();
      if (query.isEmpty) {
        setModalState(() {
          results = const [];
          loading = false;
          highlightedIndex = -1;
        });
        return;
      }
      final requestId = ++searchRequestId;
      setModalState(() {
        loading = true;
      });
      try {
        final fetched = await Future<List<Entity>>.value(searchFn(query));
        if (requestId != searchRequestId) {
          return;
        }
        final selectedIds = _selectedTags.map((tag) => tag.id).toSet();
        final filtered = fetched
            .where((entity) => !selectedIds.contains(entity.id))
            .toList();
        setModalState(() {
          results = filtered;
          loading = false;
          highlightedIndex = filtered.isNotEmpty ? 0 : -1;
        });
        if (filtered.isNotEmpty) {
          ensureHighlightedVisible(0);
        }
      } catch (_) {
        if (requestId != searchRequestId) {
          return;
        }
        setModalState(() {
          loading = false;
          results = const [];
          highlightedIndex = -1;
        });
      }
    }

    KeyEventResult handleSearchKey(
      KeyEvent event,
      void Function(void Function()) setModalState,
    ) {
      if (event is! KeyDownEvent) {
        return KeyEventResult.ignored;
      }
      final key = event.logicalKey;
      if (key == LogicalKeyboardKey.arrowDown && results.isNotEmpty) {
        setModalState(() {
          if (highlightedIndex < 0) {
            highlightedIndex = 0;
          } else {
            highlightedIndex =
                math.min(highlightedIndex + 1, results.length - 1);
          }
        });
        if (highlightedIndex >= 0) {
          ensureHighlightedVisible(highlightedIndex);
        }
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowUp && results.isNotEmpty) {
        setModalState(() {
          if (highlightedIndex <= 0) {
            highlightedIndex = 0;
          } else {
            highlightedIndex = math.max(0, highlightedIndex - 1);
          }
        });
        if (highlightedIndex >= 0) {
          ensureHighlightedVisible(highlightedIndex);
        }
        return KeyEventResult.handled;
      }
      if ((key == LogicalKeyboardKey.enter ||
              key == LogicalKeyboardKey.numpadEnter) &&
          highlightedIndex >= 0 &&
          highlightedIndex < results.length) {
        Navigator.pop(context, results[highlightedIndex]);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.escape) {
        Navigator.pop(context);
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    Entity? selectedEntity;
    try {
      selectedEntity = await showDialog<Entity>(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setModalState) {
              searchFocusNode.onKeyEvent =
                  (node, event) => handleSearchKey(event, setModalState);
              final theme = Theme.of(context);
              return AlertDialog(
                title: Text(l10n.t('entity_picker_title')),
                content: SizedBox(
                  width: 380,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: searchController,
                        focusNode: searchFocusNode,
                        autofocus: true,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search),
                          hintText: l10n.t('entity_picker_search_hint'),
                          suffixIcon: searchController.text.isEmpty
                              ? null
                              : IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    searchController.clear();
                                    searchDebounce?.cancel();
                                    setModalState(() {
                                      results = const [];
                                      highlightedIndex = -1;
                                    });
                                  },
                                ),
                        ),
                        onChanged: (value) {
                          setModalState(() {});
                          searchDebounce?.cancel();
                          searchDebounce = Timer(
                            const Duration(milliseconds: 200),
                            () => runSearch(setModalState),
                          );
                        },
                        onSubmitted: (_) => runSearch(setModalState),
                      ),
                      const SizedBox(height: 12),
                      if (loading)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(),
                        )
                      else
                        SizedBox(
                          width: double.infinity,
                          height: 260,
                          child: results.isEmpty
                              ? Center(
                                  child:
                                      Text(l10n.t('entity_picker_no_results')),
                                )
                              : ListView.builder(
                                  controller: resultsScrollController,
                                  itemCount: results.length,
                                  itemBuilder: (context, index) {
                                    final entity = results[index];
                                    final selected = highlightedIndex == index;
                                    final badge = buildBadge(entity, theme);
                                    final description =
                                        entity.data['description'] as String?;
                                    return MouseRegion(
                                      onEnter: (_) {
                                        setModalState(() {
                                          highlightedIndex = index;
                                        });
                                        ensureHighlightedVisible(index);
                                      },
                                      child: Tooltip(
                                        message: (description ?? entity.title)
                                            .trim(),
                                        waitDuration:
                                            const Duration(milliseconds: 400),
                                        child: ListTile(
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 12, vertical: 8),
                                          leading: buildAvatar(entity, theme),
                                          selected: selected,
                                          selectedTileColor: theme
                                              .colorScheme.primary
                                              .withValues(alpha: 0.08),
                                          title: Text(entity.title),
                                          subtitle: description != null
                                              ? Text(description)
                                              : null,
                                          onTap: () =>
                                              Navigator.pop(context, entity),
                                          trailing: badge == null &&
                                                  entitiesOption
                                                          ?.onRequestPreview ==
                                                      null
                                              ? null
                                              : Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    if (badge != null) badge,
                                                    if (entitiesOption
                                                            ?.onRequestPreview !=
                                                        null)
                                                      IconButton(
                                                        icon: const Icon(
                                                          Icons.remove_red_eye,
                                                        ),
                                                        tooltip: l10n.t(
                                                            'entity_picker_preview'),
                                                        onPressed: () async {
                                                          await _handleTagPreview(
                                                              entity);
                                                        },
                                                      ),
                                                  ],
                                                ),
                                        ),
                                      ),
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
                    child: Text(l10n.t('entity_picker_close')),
                  ),
                  FilledButton(
                    onPressed: loading ? null : () => runSearch(setModalState),
                    child: Text(l10n.t('entity_picker_search_button')),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      searchDebounce?.cancel();
      searchController.dispose();
      searchFocusNode.dispose();
      resultsScrollController.dispose();
    }

    final entity = selectedEntity;
    if (entity != null) {
      if (_selectedTags.any((tag) => tag.id == entity.id)) {
        return;
      }
      setState(() {
        _selectedTags = [..._selectedTags, entity];
      });
      _syncTagFocusNodes();
      controller.setComposerValue(tags: _selectedTags);
      _focusComposer(atEnd: false);
    }
  }

  void _reorderTag(Entity entity, int offset) {
    final currentIndex = _selectedTags.indexWhere((tag) => tag.id == entity.id);
    if (currentIndex == -1 || offset == 0) {
      return;
    }
    final maxIndex = _selectedTags.isEmpty ? 0 : _selectedTags.length - 1;
    final newIndex = (currentIndex + offset).clamp(0, maxIndex).toInt();
    if (newIndex == currentIndex) {
      return;
    }
    setState(() {
      final updated = List<Entity>.from(_selectedTags);
      final moved = updated.removeAt(currentIndex);
      updated.insert(newIndex, moved);
      _selectedTags = updated;
    });
    _syncTagFocusNodes();
    controller.setComposerValue(tags: _selectedTags);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusTagChipAt(newIndex);
    });
  }

  void _removeTag(Entity entity) {
    setState(() {
      _selectedTags =
          _selectedTags.where((tag) => tag.id != entity.id).toList();
    });
    _syncTagFocusNodes();
    controller.setComposerValue(tags: _selectedTags);
  }

  void _handleTagTap(Entity entity) {
    final previewFn = controller.options.entities?.onRequestPreview;
    if (previewFn != null) {
      unawaited(_handleTagPreview(entity));
    }
    controller.options.entities?.onClick?.call(entity);
  }

  Future<void> _handleTagPreview(Entity entity) async {
    final previewFn = controller.options.entities?.onRequestPreview;
    if (previewFn == null) {
      return;
    }
    final preview = await Future<EntityPreview?>.value(previewFn(entity));
    if (preview?.preview == null || !mounted) {
      return;
    }
    final widgetJson = preview!.preview!;
    final previewItem = ThreadItem(
      id: 'preview',
      threadId: controller.currentThreadId ?? 'preview',
      createdAt: DateTime.now(),
      type: 'widget',
      content: const [],
      attachments: const [],
      metadata: const {},
      raw: {'widget': widgetJson},
    );
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(entity.title),
          content: SizedBox(
            width: 360,
            child: ChatKitWidgetRenderer(
              widgetJson: widgetJson,
              controller: controller,
              item: previewItem,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _handleToolChanged(String? toolId) {
    setState(() {
      _selectedToolId = toolId;
    });
    controller.setComposerValue(selectedToolId: toolId, tags: _selectedTags);
  }

  void _handleModelChanged(String? modelId) {
    setState(() {
      _selectedModelId = modelId;
    });
    controller.setComposerValue(selectedModelId: modelId, tags: _selectedTags);
  }

  void _upsertItem(ThreadItem item) {
    final index = _items.indexWhere((element) => element.id == item.id);
    if (index == -1) {
      _items = [..._items, item]
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    } else {
      final updated = [..._items];
      updated[index] = item;
      _items = updated;
    }
  }

  Future<void> _handleSend() async {
    if (_isStreaming || !_composerEnabled || _authExpired) return;
    final text = _composerController.text.trim();
    if (text.isEmpty && _attachments.isEmpty) {
      return;
    }
    final previousText = _composerController.text;
    final previousSelection = _composerController.selection;
    final previousAttachments = _attachments;
    final previousTags = _selectedTags;
    final attachmentPayloads =
        _attachments.map((a) => a.toJson()).toList(growable: false);

    _composerController.clear();
    setState(() {
      _attachments = const [];
      _selectedTags = const [];
    });
    try {
      await controller.sendUserMessage(
        text: text,
        attachments: attachmentPayloads,
        tags: previousTags,
      );
    } catch (error) {
      if (!mounted) return;
      _composerController
        ..text = previousText
        ..selection = previousSelection;
      setState(() {
        _attachments = previousAttachments;
        _selectedTags = previousTags;
      });
      controller.setComposerValue(
        text: previousText,
        attachments: previousAttachments.map((a) => a.toJson()).toList(),
        tags: previousTags,
      );
      if (!mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (!_suppressSnackbars && messenger != null) {
        messenger.showSnackBar(
          SnackBar(content: Text('Failed to send message: $error')),
        );
      }
    }
  }

  void _syncComposerState() {
    controller.setComposerValue(
      attachments: _attachments.map((a) => a.toJson()).toList(),
      tags: _selectedTags,
    );
  }

  Future<void> _handleAttachment() async {
    if (!_composerEnabled || _authExpired) {
      return;
    }
    final options = controller.options.composer?.attachments;
    if (options == null || !options.enabled) {
      return;
    }
    final l10n = _localizations;
    try {
      final allowMultiple = options.maxCount == null || options.maxCount! > 1;
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: allowMultiple,
        withData: true,
        type: FileType.any,
        allowedExtensions: options.accept?.values.expand((e) => e).toList(),
      );
      if (result == null || result.files.isEmpty) {
        return;
      }

      final payloads = <_AttachmentPayload>[];
      for (final file in result.files) {
        final bytes = file.bytes;
        if (bytes == null) {
          if (!mounted) continue;
          final messenger = ScaffoldMessenger.maybeOf(context);
          if (!_suppressSnackbars && messenger != null) {
            messenger.showSnackBar(
              SnackBar(
                content: Text(
                  '${file.name}: ${l10n.t('attachment_pick_failed')}',
                ),
              ),
            );
          }
          continue;
        }
        final header = bytes.length >= 12 ? bytes.sublist(0, 12) : bytes;
        final mimeType = lookupMimeType(
              file.name,
              headerBytes: header,
            ) ??
            'application/octet-stream';
        final size = file.size > 0 ? file.size : bytes.length;
        payloads.add(
          _AttachmentPayload(
            name: file.name,
            bytes: Uint8List.fromList(bytes),
            mimeType: mimeType,
            size: size,
          ),
        );
      }
      if (payloads.isEmpty) {
        return;
      }
      await _ingestAttachmentPayloads(payloads, options: options);
    } catch (error) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (!_suppressSnackbars && messenger != null) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('${l10n.t('attachment_pick_failed')} $error'),
          ),
        );
      }
    }
  }

  Future<void> _handleDroppedFiles(List<XFile> files) async {
    final options = controller.options.composer?.attachments;
    if (options == null || !options.enabled || files.isEmpty) {
      return;
    }
    final l10n = _localizations;
    final payloads = <_AttachmentPayload>[];
    for (final file in files) {
      try {
        final bytes = await file.readAsBytes();
        final header = bytes.length >= 12 ? bytes.sublist(0, 12) : bytes;
        final mimeType = (file.mimeType ??
                lookupMimeType(
                  file.name,
                  headerBytes: header,
                )) ??
            'application/octet-stream';
        final name = file.name.isEmpty ? 'attachment' : file.name;
        payloads.add(
          _AttachmentPayload(
            name: name,
            bytes: bytes,
            mimeType: mimeType,
            size: bytes.length,
          ),
        );
      } on Object catch (error) {
        if (!mounted) continue;
        final name = file.name.isEmpty ? 'attachment' : file.name;
        final messenger = ScaffoldMessenger.maybeOf(context);
        if (!_suppressSnackbars && messenger != null) {
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                '$name: ${l10n.t('attachment_pick_failed')} $error',
              ),
            ),
          );
        }
      }
    }
    if (payloads.isEmpty) {
      return;
    }
    await _ingestAttachmentPayloads(payloads, options: options);
  }

  Future<void> _ingestAttachmentPayloads(
    List<_AttachmentPayload> payloads, {
    required ComposerAttachmentOption options,
  }) async {
    if (payloads.isEmpty) {
      return;
    }
    final l10n = _localizations;
    final activePending = _pendingUploads
        .where((upload) => !upload.cancelled && !upload.hasError)
        .length;
    final currentCount = _attachments.length + activePending;
    int? availableSlots = options.maxCount == null
        ? null
        : math.max(0, options.maxCount! - currentCount);
    final accepted = <_AttachmentPayload>[];
    final rejections = <_FileRejection>[];

    for (final payload in payloads) {
      if (availableSlots != null && availableSlots <= 0) {
        rejections.add(
          _FileRejection(
            name: payload.name,
            type: _RejectionType.limit,
          ),
        );
        continue;
      }
      final rejection = _validateAttachmentPayload(payload, options);
      if (rejection != null) {
        rejections.add(rejection);
        continue;
      }
      accepted.add(payload);
      if (availableSlots != null) {
        availableSlots -= 1;
      }
    }

    if (rejections.isNotEmpty && mounted) {
      final message = _buildRejectionMessage(rejections, l10n);
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (!_suppressSnackbars && messenger != null) {
        messenger.showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    }

    for (final payload in accepted) {
      final upload = _PendingUpload(
        id: UniqueKey().toString(),
        name: payload.name,
        mimeType: payload.mimeType,
        size: payload.size,
        bytes: payload.bytes,
      );
      await _runUpload(upload);
      if (!mounted) {
        return;
      }
    }
  }

  _FileRejection? _validateAttachmentPayload(
    _AttachmentPayload payload,
    ComposerAttachmentOption options,
  ) {
    final maxSize = options.maxSize;
    if (maxSize != null && payload.size > maxSize) {
      return _FileRejection(
        name: payload.name,
        type: _RejectionType.size,
        detail: _formatBytes(maxSize),
      );
    }
    final accept = options.accept;
    if (accept != null && accept.isNotEmpty) {
      if (!_matchesAccept(payload, accept)) {
        return _FileRejection(
          name: payload.name,
          type: _RejectionType.type,
        );
      }
    }
    return null;
  }

  bool _matchesAccept(
    _AttachmentPayload payload,
    Map<String, List<String>> accept,
  ) {
    if (accept.isEmpty) {
      return true;
    }
    final mime = payload.mimeType.toLowerCase();
    final extension = _extensionFromName(payload.name)?.toLowerCase();

    for (final entry in accept.entries) {
      final pattern = entry.key.toLowerCase();
      if (pattern == '*/*') {
        return true;
      }
      if (pattern.endsWith('/*')) {
        final prefix = pattern.split('/').first;
        if (mime.startsWith('$prefix/')) {
          return true;
        }
      } else if (pattern.isNotEmpty && mime == pattern) {
        return true;
      }
      for (final ext in entry.value) {
        final normalized = ext.toLowerCase().replaceAll('.', '');
        if (normalized.isEmpty) {
          continue;
        }
        if (extension == normalized) {
          return true;
        }
      }
    }
    return false;
  }

  String _buildRejectionMessage(
    List<_FileRejection> rejections,
    ChatKitLocalizations l10n,
  ) {
    final primary = rejections.first;
    final reason = _describeRejection(primary, l10n);
    if (rejections.length == 1) {
      return '${primary.name}: $reason';
    }
    return '${l10n.t('attachment_rejected_multiple')} (${rejections.length}) $reason';
  }

  String _describeRejection(
    _FileRejection rejection,
    ChatKitLocalizations l10n,
  ) {
    switch (rejection.type) {
      case _RejectionType.limit:
        return l10n.t('attachment_limit_reached');
      case _RejectionType.type:
        return l10n.t('attachment_rejected_type');
      case _RejectionType.size:
        final base = l10n.t('attachment_rejected_size');
        if (rejection.detail != null && rejection.detail!.isNotEmpty) {
          return '$base (${rejection.detail})';
        }
        return base;
    }
  }

  Future<void> _runUpload(
    _PendingUpload upload, {
    bool isRetry = false,
  }) async {
    final l10n = _localizations;
    if (!mounted) {
      return;
    }

    setState(() {
      if (!isRetry) {
        _pendingUploads = [..._pendingUploads, upload];
      }
      upload
        ..error = null
        ..cancelled = false
        ..inFlight = true
        ..sent = 0
        ..total = upload.size;
      _updateUploadingStatus();
    });

    ChatKitAttachment? attachment;
    Object? error;

    try {
      attachment = await controller.registerAttachment(
        name: upload.name,
        bytes: upload.bytes,
        mimeType: upload.mimeType,
        size: upload.size,
        onProgress: (sent, total) {
          if (!mounted) {
            return;
          }
          setState(() {
            upload.sent = sent;
            upload.total = total;
          });
        },
        isCancelled: () => upload.cancelled,
      );
    } on Object catch (err) {
      if (!upload.cancelled) {
        error = err;
      }
    }

    if (!mounted) {
      return;
    }

    if (upload.cancelled) {
      setState(() {
        upload.inFlight = false;
        _pendingUploads =
            _pendingUploads.where((item) => item != upload).toList();
        _updateUploadingStatus();
      });
      return;
    }

    if (error != null || attachment == null) {
      final errorText = error?.toString();
      setState(() {
        upload.error = error ?? Exception('upload_failed');
        upload.inFlight = false;
        _updateUploadingStatus();
      });
      if (mounted) {
        final message = errorText == null || errorText.isEmpty
            ? l10n.t('attachment_upload_failed')
            : '${l10n.t('attachment_upload_failed')} $errorText';
        final messenger = ScaffoldMessenger.maybeOf(context);
        if (!_suppressSnackbars && messenger != null) {
          messenger.showSnackBar(
            SnackBar(content: Text(message)),
          );
        }
      }
      return;
    }

    final resolved = _ensureAttachmentSize(attachment, upload.size);
    setState(() {
      upload.inFlight = false;
      _pendingUploads =
          _pendingUploads.where((item) => item != upload).toList();
      _updateUploadingStatus();
      _attachments = [..._attachments, resolved];
    });
    _syncComposerState();
  }

  @visibleForTesting
  Future<void> debugAddAttachment({
    required String name,
    required Uint8List bytes,
    required String mimeType,
    int? size,
    ComposerAttachmentOption options = const ComposerAttachmentOption(
      enabled: true,
    ),
  }) {
    return _ingestAttachmentPayloads(
      [
        _AttachmentPayload(
          name: name,
          bytes: bytes,
          mimeType: mimeType,
          size: size ?? bytes.length,
        ),
      ],
      options: options,
    );
  }

  @visibleForTesting
  Future<void> debugPerformShareTarget({
    required ShareTargetOption target,
    required String shareText,
    ShareActionsOption? shareActions,
  }) {
    return _performShareTarget(
      target: target,
      shareText: shareText,
      threadId: 'debug_thread',
      itemId: 'debug_item',
      shareActions: shareActions,
      localizations: _localizations,
    );
  }

  @visibleForTesting
  Future<void> debugRetryUpload(_PendingUpload upload) {
    return _retryUpload(upload);
  }

  @visibleForTesting
  List<_PendingUpload> get debugPendingUploads => _pendingUploads;

  @visibleForTesting
  set debugSuppressSnackbars(bool value) => _suppressSnackbars = value;

  void _updateUploadingStatus() {
    _isUploading =
        _pendingUploads.any((upload) => upload.inFlight && !upload.cancelled);
  }

  Future<void> _retryUpload(_PendingUpload upload) async {
    if (upload.inFlight) {
      return;
    }
    await _runUpload(upload, isRetry: true);
  }

  void _removeUpload(_PendingUpload upload) {
    setState(() {
      _pendingUploads =
          _pendingUploads.where((item) => item != upload).toList();
      _updateUploadingStatus();
    });
  }

  void _handleDropEnter() {
    _dropDepth += 1;
    _activateDropOverlay();
  }

  void _handleDropExit() {
    _dropDepth = math.max(0, _dropDepth - 1);
    if (_dropDepth == 0) {
      _deactivateDropOverlay();
    }
  }

  void _activateDropOverlay() {
    if (_isDropTargetActive) {
      return;
    }
    setState(() {
      _isDropTargetActive = true;
    });
  }

  void _deactivateDropOverlay() {
    if (!_isDropTargetActive) {
      return;
    }
    setState(() {
      _isDropTargetActive = false;
    });
  }

  void _cancelUpload(_PendingUpload upload) {
    setState(() {
      upload.cancelled = true;
      _pendingUploads =
          _pendingUploads.where((item) => item != upload).toList();
      _updateUploadingStatus();
    });
  }

  void _scheduleScrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Widget _wrapWithChatKitTheme(BuildContext context, Widget child) {
    final themeOption = controller.options.resolvedTheme;
    if (themeOption == null) {
      return child;
    }
    final themeData = _resolveTheme(context, themeOption);
    return Theme(data: themeData, child: child);
  }

  ThemeData _resolveTheme(BuildContext context, ThemeOption option) {
    ThemeData base;
    switch (option.colorScheme) {
      case ColorSchemeOption.dark:
        base = ThemeData.dark();
        break;
      case ColorSchemeOption.light:
        base = ThemeData.light();
        break;
      case ColorSchemeOption.system:
        final brightness = MediaQuery.platformBrightnessOf(context);
        base = brightness == Brightness.dark
            ? ThemeData.dark()
            : ThemeData.light();
        break;
      case null:
        base = Theme.of(context);
        break;
    }

    var scheme = base.colorScheme;
    final accent = option.color?.accent;
    if (accent != null) {
      scheme = scheme.copyWith(
        primary: _parseColor(accent.primary) ?? scheme.primary,
        onPrimary: _parseColor(accent.onPrimary) ?? scheme.onPrimary,
        secondary: _parseColor(accent.secondary) ?? scheme.secondary,
        onSecondary: _parseColor(accent.onSecondary) ?? scheme.onSecondary,
      );
    }

    final surface = option.color?.surface;
    Color? scaffoldBackground;
    Color? canvasColor;
    if (surface != null) {
      final primarySurface = _parseColor(surface.primary);
      final secondarySurface = _parseColor(surface.secondary);
      final tertiarySurface = _parseColor(surface.tertiary);
      final quaternarySurface = _parseColor(surface.quaternary);
      scheme = scheme.copyWith(
        surface: primarySurface ?? scheme.surface,
        surfaceTint: secondarySurface ?? scheme.surfaceTint,
      );
      scaffoldBackground = tertiarySurface ?? primarySurface;
      canvasColor = quaternarySurface;
    }

    var theme = base.copyWith(colorScheme: scheme);
    if (scaffoldBackground != null || canvasColor != null) {
      theme = theme.copyWith(
        scaffoldBackgroundColor:
            scaffoldBackground ?? theme.scaffoldBackgroundColor,
        canvasColor: canvasColor ?? theme.canvasColor,
      );
    }

    var textTheme = theme.textTheme;
    var primaryTextTheme = theme.primaryTextTheme;

    final grayscale = option.color?.grayscale;
    if (grayscale != null) {
      final displayColor = _parseColor(grayscale.label0);
      final bodyColor = _parseColor(grayscale.label1);
      textTheme = textTheme.apply(
        displayColor: displayColor,
        bodyColor: bodyColor,
      );
      primaryTextTheme = primaryTextTheme.apply(
        displayColor: displayColor,
        bodyColor: bodyColor,
      );
      final background = _parseColor(grayscale.background);
      if (background != null) {
        theme = theme.copyWith(scaffoldBackgroundColor: background);
      }
      final borderColor = _parseColor(grayscale.border);
      if (borderColor != null) {
        theme = theme.copyWith(dividerColor: borderColor);
      }
      final shadowColor = _parseColor(grayscale.shadow);
      if (shadowColor != null) {
        theme = theme.copyWith(shadowColor: shadowColor);
      }
    }

    final typography = option.typography;
    if (typography != null) {
      textTheme = textTheme.apply(fontFamily: typography.fontFamily);
      primaryTextTheme =
          primaryTextTheme.apply(fontFamily: typography.fontFamily);
    }

    theme = theme.copyWith(
      textTheme: textTheme,
      primaryTextTheme: primaryTextTheme,
    );

    final radiusValue = option.shapes?.radius;
    if (radiusValue != null) {
      final borderRadius = BorderRadius.circular(radiusValue);
      final buttonShape = RoundedRectangleBorder(borderRadius: borderRadius);
      theme = theme.copyWith(
        cardTheme: theme.cardTheme.copyWith(
          shape: RoundedRectangleBorder(borderRadius: borderRadius),
        ),
        dialogTheme: theme.dialogTheme.copyWith(
          shape: RoundedRectangleBorder(borderRadius: borderRadius),
        ),
        bottomSheetTheme: theme.bottomSheetTheme.copyWith(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(radiusValue),
            ),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: _withShape(theme.elevatedButtonTheme.style, buttonShape),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: _withShape(theme.filledButtonTheme.style, buttonShape),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: _withShape(theme.outlinedButtonTheme.style, buttonShape),
        ),
        chipTheme: theme.chipTheme.copyWith(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusValue / 2),
          ),
        ),
      );
    }

    if (option.elevations?.surface != null) {
      theme = theme.copyWith(
        cardTheme: theme.cardTheme.copyWith(
          elevation: option.elevations?.surface,
        ),
        dialogTheme: theme.dialogTheme.copyWith(
          elevation: option.elevations?.surface,
        ),
      );
    }

    final gradient =
        _buildGradient(option.backgroundGradient ?? option.color?.gradients);

    final tokens = ChatKitThemeTokens(
      backgroundGradient: gradient,
      surfaceElevation: option.elevations?.surface,
      historyElevation: option.elevations?.history,
      historyStyle: _componentStyleFromOptions(
        option.components?.history,
        option.elevations?.history,
      ),
      composerStyle: _componentStyleFromOptions(
        option.components?.composer,
        option.elevations?.composer,
      ),
      assistantBubbleStyle: _componentStyleFromOptions(
        option.components?.assistantBubble,
        option.elevations?.assistantBubble,
      ),
      userBubbleStyle: _componentStyleFromOptions(
        option.components?.userBubble,
        option.elevations?.userBubble,
      ),
    );

    final existingExtensions = theme.extensions.values.toList();
    theme = theme.copyWith(
      extensions: [
        ...existingExtensions,
        tokens,
      ],
    );

    return theme;
  }

  Gradient? _buildGradient(ThemeGradientOptions? options) {
    if (options == null || options.colors.isEmpty) {
      return null;
    }
    final colors = options.colors
        .map(_parseColor)
        .whereType<Color>()
        .toList(growable: false);
    if (colors.length < 2) {
      return null;
    }
    final angle = (options.angle ?? 0) * math.pi / 180;
    final dx = math.cos(angle);
    final dy = math.sin(angle);
    final begin = Alignment(-dx, -dy);
    final end = Alignment(dx, dy);
    return LinearGradient(
      colors: colors,
      begin: begin,
      end: end,
    );
  }

  ComponentStyleToken? _componentStyleFromOptions(
    ThemeComponentStyle? style,
    double? fallbackElevation,
  ) {
    if (style == null && fallbackElevation == null) {
      return null;
    }
    return ComponentStyleToken(
      backgroundColor: _parseColor(style?.background),
      textColor: _parseColor(style?.text),
      borderColor: _parseColor(style?.border),
      elevation: style?.elevation ?? fallbackElevation,
      radius: style?.radius,
    );
  }

  ButtonStyle _withShape(ButtonStyle? style, OutlinedBorder shape) {
    return (style ?? const ButtonStyle()).copyWith(
      shape: WidgetStatePropertyAll<OutlinedBorder>(shape),
    );
  }

  Color? _parseColor(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    var hex = value.replaceFirst('#', '');
    if (hex.length == 6) {
      hex = 'ff' + hex;
    }
    final int? intValue = int.tryParse(hex, radix: 16);
    if (intValue == null) {
      return null;
    }
    return Color(intValue);
  }

  @override
  Widget build(BuildContext context) {
    _ensureLocaleBundle();
    final theme = Theme.of(context);
    final l10n = _localizations;
    final composerOptions = controller.options.composer;
    final toolOptions = composerOptions?.tools ?? const <ToolOption>[];
    final modelOptions = composerOptions?.models ?? const <ModelOption>[];
    final selectedTool = toolOptions.firstWhereOrNull(
      (tool) => tool.id == _selectedToolId,
    );
    final effectiveModelId = _selectedModelId ??
        modelOptions.firstWhereOrNull((m) => m.defaultSelected)?.id;
    var placeholder = selectedTool?.placeholderOverride ??
        composerOptions?.placeholder ??
        l10n.t('composer_input_placeholder');

    final composerLockReason = _authExpired
        ? 'auth'
        : (_composerEnabled ? null : _composerDisabledReason);
    final composerLocked = composerLockReason != null;
    String? lockMessage;
    if (composerLockReason == 'auth') {
      lockMessage = l10n.t('composer_disabled_auth');
      placeholder = l10n.t('composer_disabled_auth');
    } else if (composerLockReason == 'rate_limit') {
      final baseMessage = l10n.t('composer_disabled_rate_limit');
      final countdown = _formatRetryCountdown(l10n);
      lockMessage = countdown == null ? baseMessage : '$baseMessage $countdown';
      placeholder = baseMessage;
    }

    final composerBusy = _isStreaming || _isUploading;
    final composerBase = _Composer(
      composerController: _composerController,
      focusNode: _composerFocusNode,
      onSend: _handleSend,
      onAttachment:
          _attachmentsEnabled && !composerLocked ? _handleAttachment : null,
      attachments: _attachments,
      pendingUploads: _pendingUploads,
      onRemoveAttachment: (attachment) {
        setState(() {
          _attachments =
              _attachments.where((a) => a.id != attachment.id).toList();
        });
        _syncComposerState();
      },
      onTextChanged: _handleComposerChanged,
      onAddTag: _canAddEntities ? _openEntityPicker : null,
      onRemoveTag: _removeTag,
      onTapTag: _handleTagTap,
      onPreviewTag: _handleTagPreview,
      tags: _selectedTags,
      tools: toolOptions.isEmpty ? null : toolOptions,
      models: modelOptions.isEmpty ? null : modelOptions,
      selectedToolId: _selectedToolId,
      selectedModelId: effectiveModelId,
      onToolChanged: _handleToolChanged,
      onModelChanged: _handleModelChanged,
      localizations: l10n,
      placeholder: placeholder,
      isStreaming: composerBusy,
      isComposerLocked: composerLocked,
      lockMessage: lockMessage,
      onCancelUpload: _cancelUpload,
      onRetryUpload: _retryUpload,
      onRemoveFailedUpload: _removeUpload,
      composerFieldLink: _composerFieldLink,
      tagFocusNodes: _tagFocusNodes,
      tagTooltipBuilder: _entityTooltip,
      tagAvatarBuilder: _entityAvatar,
    );

    final allowAttachments = _attachmentsEnabled && !composerLocked;
    final composerSection = !allowAttachments
        ? composerBase
        : DropTarget(
            onDragEntered: (_) => _handleDropEnter(),
            onDragUpdated: (_) => _activateDropOverlay(),
            onDragExited: (_) => _handleDropExit(),
            onDragDone: (details) async {
              _dropDepth = 0;
              _deactivateDropOverlay();
              await _handleDroppedFiles(details.files);
            },
            child: Stack(
              fit: StackFit.passthrough,
              children: [
                composerBase,
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedOpacity(
                      opacity: _isDropTargetActive ? 1 : 0,
                      duration: const Duration(milliseconds: 150),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: theme.colorScheme.primary,
                              width: 2,
                            ),
                            color: theme.colorScheme.primary
                                .withValues(alpha: 0.08),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.cloud_upload_outlined,
                                  size: 36,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  l10n.t('attachment_drop_prompt'),
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );

    final column = Column(
      children: [
        if (_authExpired)
          _AuthExpiredBanner(
            localizations: l10n,
            onDismiss: () => setState(() => _authExpired = false),
          ),
        if (controller.options.header?.enabled ?? true)
          _ChatHeader(
            thread: _thread,
            options: controller.options.header,
            historyEnabled: _historyEnabled,
            isHistoryOpen: _historyOpen,
            onToggleHistory: _historyEnabled ? _toggleHistory : null,
            localizations: l10n,
          ),
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
            ),
            child: _items.isEmpty
                ? _StartScreen(options: controller.options.startScreen)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      return _ChatItemView(
                        key: ValueKey(item.id),
                        item: item,
                        controller: controller,
                        actions: controller.options.threadItemActions,
                        localizations: l10n,
                      );
                    },
                  ),
          ),
        ),
        if (controller.options.disclaimer != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Builder(
              builder: (context) {
                final disclaimer = controller.options.disclaimer!;
                final baseColor = theme.textTheme.bodySmall?.color ??
                    theme.colorScheme.onSurface;
                final textColor = disclaimer.highContrast == true
                    ? theme.colorScheme.onSurface
                    : baseColor.withValues(alpha: 0.7);
                return Text(
                  disclaimer.text,
                  style: theme.textTheme.bodySmall?.copyWith(color: textColor),
                );
              },
            ),
          ),
        if (_banners.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Column(
              children: [
                for (final banner in _banners)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _NoticeBanner(
                      banner: banner,
                      localizations: l10n,
                      onClose: () => _dismissBanner(banner.id),
                    ),
                  ),
              ],
            ),
          ),
        composerSection,
      ],
    );

    final historyState = _currentHistoryState;
    final visibleThreads = _filterHistoryThreads(historyState.threads);
    final pinnedThreads = <ThreadMetadata>[];
    final otherThreads = <ThreadMetadata>[];
    for (final thread in visibleThreads) {
      if (_isThreadPinned(thread)) {
        pinnedThreads.add(thread);
      } else {
        otherThreads.add(thread);
      }
    }
    final historyPanelWidget = _HistoryPanel(
      localizations: l10n,
      section: _activeHistorySection,
      onSectionChanged: _handleHistorySectionChanged,
      searchController: _historySearchController,
      onSearchChanged: _handleHistorySearchChanged,
      onSearchCleared: _clearHistorySearch,
      pinnedThreads: pinnedThreads,
      threads: otherThreads,
      loadingInitial: historyState.loadingInitial,
      loadingMore: historyState.loadingMore,
      error: historyState.error,
      onRefresh: () => _refreshHistory(
        section: _activeHistorySection,
        reset: true,
      ),
      onSelect: _handleSelectThread,
      onDelete: controller.options.history?.showDelete == true
          ? _handleDeleteThread
          : null,
      onRename: controller.options.history?.showRename == true
          ? _handleRenameThread
          : null,
      currentThreadId: controller.currentThreadId,
      hasMore: historyState.hasMore,
      scrollController: _historyScrollController,
      onLoadMore: historyState.hasMore ? _loadMoreHistory : null,
    );

    final layoutSize = _layoutSizeOf(context);
    Widget mainArea;
    if (layoutSize == _LayoutSize.compact) {
      final historyHeight = math.min(
        MediaQuery.of(context).size.height * 0.5,
        420.0,
      );
      mainArea = Column(
        children: [
          if (_historyEnabled && _historyOpen)
            SizedBox(
              height: historyHeight,
              child: historyPanelWidget,
            ),
          Expanded(child: column),
        ],
      );
    } else {
      final historyWidth = layoutSize == _LayoutSize.medium ? 280.0 : 320.0;
      mainArea = Row(
        children: [
          if (_historyEnabled && _historyOpen)
            SizedBox(
              width: historyWidth,
              child: historyPanelWidget,
            ),
          Expanded(child: column),
        ],
      );
    }

    return _wrapWithChatKitTheme(
      context,
      mainArea,
    );
  }
}

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({
    required this.thread,
    this.options,
    required this.historyEnabled,
    required this.isHistoryOpen,
    this.onToggleHistory,
    required this.localizations,
  });

  final Thread? thread;
  final HeaderOption? options;
  final bool historyEnabled;
  final bool isHistoryOpen;
  final VoidCallback? onToggleHistory;
  final ChatKitLocalizations localizations;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleText =
        options?.title?.text ?? thread?.metadata.title ?? 'Conversation';
    Widget leading;
    if (options?.leftAction case final action?) {
      leading = _HeaderButton(action: action);
    } else if (historyEnabled && onToggleHistory != null) {
      leading = IconButton(
        icon: Icon(isHistoryOpen ? Icons.close_fullscreen : Icons.history),
        tooltip: localizations.t('history_title'),
        onPressed: onToggleHistory,
      );
    } else {
      leading = const SizedBox.shrink();
    }

    Widget trailing;
    if (options?.rightAction case final action?) {
      trailing = _HeaderButton(action: action);
    } else {
      trailing = const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border:
            Border(bottom: BorderSide(color: theme.colorScheme.outlineVariant)),
      ),
      child: Row(
        children: [
          SizedBox(width: 48, child: Center(child: leading)),
          Expanded(
            child: Text(
              titleText,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(width: 48, child: Center(child: trailing)),
        ],
      ),
    );
  }
}

class _HistoryPanel extends StatelessWidget {
  const _HistoryPanel({
    required this.localizations,
    required this.section,
    required this.onSectionChanged,
    required this.searchController,
    required this.onSearchChanged,
    required this.onSearchCleared,
    required this.pinnedThreads,
    required this.threads,
    required this.loadingInitial,
    required this.loadingMore,
    required this.onRefresh,
    required this.onSelect,
    this.onDelete,
    this.onRename,
    required this.currentThreadId,
    this.error,
    required this.hasMore,
    this.onLoadMore,
    required this.scrollController,
  });

  final ChatKitLocalizations localizations;
  final _HistorySection section;
  final ValueChanged<_HistorySection> onSectionChanged;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchCleared;
  final List<ThreadMetadata> pinnedThreads;
  final List<ThreadMetadata> threads;
  final bool loadingInitial;
  final bool loadingMore;
  final Future<void> Function() onRefresh;
  final void Function(String?) onSelect;
  final void Function(String threadId)? onDelete;
  final void Function(ThreadMetadata thread)? onRename;
  final String? currentThreadId;
  final String? error;
  final bool hasMore;
  final Future<void> Function()? onLoadMore;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final searchValue = searchController.text;
    final showClear = searchValue.isNotEmpty;
    final dateFormatter = DateFormat.yMMMd().add_jm();
    final tokens = theme.extension<ChatKitThemeTokens>();
    final style = tokens?.historyStyle;
    final panelBackground = style?.backgroundColor ?? theme.colorScheme.surface;
    final panelTextColor = style?.textColor;
    final panelBorderColor = style?.borderColor;
    final panelElevation = style?.elevation ?? tokens?.historyElevation ?? 4;
    final panelRadius = style?.radius ?? 0;

    Widget buildThreadTile(ThreadMetadata thread, {required bool pinned}) {
      final selected = currentThreadId == thread.id;
      final title = (thread.title ?? '').trim().isEmpty
          ? localizations.t('history_thread_untitled')
          : thread.title!;

      final badges = <Widget>[];
      if (thread.status.isClosed) {
        badges.add(
          _HistoryStatusChip(
            label: localizations.t('history_status_archived'),
            background: theme.colorScheme.errorContainer,
            foreground: theme.colorScheme.onErrorContainer,
          ),
        );
      } else if (thread.status.isLocked) {
        badges.add(
          _HistoryStatusChip(
            label: localizations.t('history_status_locked'),
            background: theme.colorScheme.tertiaryContainer,
            foreground: theme.colorScheme.onTertiaryContainer,
          ),
        );
      }
      if (_isShared(thread)) {
        badges.add(
          _HistoryStatusChip(
            label: localizations.t('history_status_shared'),
            background: theme.colorScheme.secondaryContainer,
            foreground: theme.colorScheme.onSecondaryContainer,
          ),
        );
      }

      final trailingActions = <Widget>[];
      if (onRename != null) {
        trailingActions.add(
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: localizations.t('history_rename'),
            onPressed: () => onRename!(thread),
          ),
        );
      }
      if (onDelete != null) {
        trailingActions.add(
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: localizations.t('history_delete'),
            onPressed: () => onDelete!(thread.id),
          ),
        );
      }

      return ListTile(
        dense: false,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        selected: selected,
        leading: Icon(
          pinned ? Icons.push_pin_outlined : Icons.chat_bubble_outline,
          color: pinned
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurfaceVariant,
        ),
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: badges.isEmpty
            ? Text(
                dateFormatter.format(thread.createdAt),
                style: textTheme.bodySmall,
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dateFormatter.format(thread.createdAt),
                    style: textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: badges,
                  ),
                ],
              ),
        onTap: () => onSelect(thread.id),
        trailing: trailingActions.isEmpty
            ? null
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: trailingActions,
              ),
      );
    }

    final listChildren = <Widget>[];
    if (error != null && (pinnedThreads.isNotEmpty || threads.isNotEmpty)) {
      listChildren.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: _HistoryErrorBanner(
            message: error!,
            localizations: localizations,
            onRetry: onRefresh,
          ),
        ),
      );
    }

    if (pinnedThreads.isNotEmpty) {
      listChildren.add(
        _HistorySectionHeader(
          label: localizations.t('history_pinned_section'),
        ),
      );
      for (final thread in pinnedThreads) {
        listChildren.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: buildThreadTile(thread, pinned: true),
          ),
        );
      }
      if (threads.isNotEmpty) {
        listChildren.add(const SizedBox(height: 8));
      }
    }

    if (threads.isNotEmpty) {
      listChildren.add(
        _HistorySectionHeader(
          label: localizations.t(section.localizationKey),
        ),
      );
      for (final thread in threads) {
        listChildren.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: buildThreadTile(thread, pinned: false),
          ),
        );
      }
    }

    if (loadingMore) {
      listChildren.add(const SizedBox(height: 8));
      for (var i = 0; i < 3; i++) {
        listChildren.add(
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: _HistorySkeletonTile(),
          ),
        );
      }
    } else if (hasMore && onLoadMore != null) {
      listChildren.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: OutlinedButton.icon(
            onPressed: () => onLoadMore!(),
            icon: const Icon(Icons.history),
            label: Text(localizations.t('history_load_more')),
          ),
        ),
      );
    }

    Widget buildBody() {
      if (loadingInitial) {
        return const _HistorySkeletonList();
      }
      if (pinnedThreads.isEmpty && threads.isEmpty) {
        if (error != null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _HistoryErrorBanner(
                message: error!,
                localizations: localizations,
                onRetry: onRefresh,
              ),
            ),
          );
        }
        return _HistoryEmptyState(
          icon: searchValue.isNotEmpty
              ? Icons.search_off_outlined
              : Icons.chat_bubble_outline,
          message: searchValue.isNotEmpty
              ? localizations.t('history_empty_search')
              : localizations.t('history_empty'),
        );
      }
      return ListView(
        controller: scrollController,
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: listChildren,
      );
    }

    Widget panelContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  localizations.t('history_title'),
                  style: textTheme.titleMedium,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: localizations.t('history_refresh'),
                onPressed: () => onRefresh(),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: searchController,
            onChanged: onSearchChanged,
            onSubmitted: (_) => onRefresh(),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: localizations.t('history_search_hint'),
              suffixIcon: showClear
                  ? IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: localizations.t('history_clear_search'),
                      onPressed: onSearchCleared,
                    )
                  : null,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final value in _HistorySection.values)
                ChoiceChip(
                  label: Text(localizations.t(value.localizationKey)),
                  selected: section == value,
                  onSelected: (selected) {
                    if (selected) {
                      onSectionChanged(value);
                    }
                  },
                ),
            ],
          ),
        ),
        Expanded(child: buildBody()),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: () => onSelect(null),
            icon: const Icon(Icons.add),
            label: Text(localizations.t('history_new_chat')),
          ),
        ),
      ],
    );

    if (panelTextColor != null) {
      panelContent = IconTheme.merge(
        data: IconThemeData(color: panelTextColor),
        child: DefaultTextStyle.merge(
          style: textTheme.bodyMedium?.copyWith(color: panelTextColor),
          child: panelContent,
        ),
      );
    }

    return Material(
      color: panelBackground,
      elevation: panelElevation,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(panelRadius),
        side: panelBorderColor == null
            ? BorderSide.none
            : BorderSide(color: panelBorderColor),
      ),
      child: panelContent,
    );
  }

  bool _isShared(ThreadMetadata thread) {
    final shared = thread.metadata['shared'];
    if (shared is bool) return shared;
    if (shared is num) return shared != 0;
    if (shared is String) {
      final normalized = shared.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
        return true;
      }
    }
    final visibility = thread.metadata['visibility'];
    if (visibility is String && visibility.trim().toLowerCase() == 'shared') {
      return true;
    }
    return false;
  }
}

class _HistorySectionHeader extends StatelessWidget {
  const _HistorySectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _HistoryStatusChip extends StatelessWidget {
  const _HistoryStatusChip({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(color: foreground),
      ),
    );
  }
}

class _HistoryErrorBanner extends StatelessWidget {
  const _HistoryErrorBanner({
    required this.message,
    required this.localizations,
    required this.onRetry,
  });

  final String message;
  final ChatKitLocalizations localizations;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline,
            size: 20,
            color: theme.colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
          TextButton(
            onPressed: () => onRetry(),
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.onErrorContainer,
            ),
            child: Text(localizations.t('history_retry')),
          ),
        ],
      ),
    );
  }
}

class _HistoryEmptyState extends StatelessWidget {
  const _HistoryEmptyState({
    required this.icon,
    required this.message,
  });

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _HistorySkeletonList extends StatelessWidget {
  const _HistorySkeletonList();

  static const int _itemCount = 6;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _itemCount,
      itemBuilder: (context, index) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 6),
        child: _HistorySkeletonTile(),
      ),
    );
  }
}

class _HistorySkeletonTile extends StatelessWidget {
  const _HistorySkeletonTile();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 14,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                height: 12,
                width: 120,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

enum _HistorySection { recent, archived, shared }

extension _HistorySectionMetadata on _HistorySection {
  String get localizationKey => switch (this) {
        _HistorySection.recent => 'history_section_recent',
        _HistorySection.archived => 'history_section_archived',
        _HistorySection.shared => 'history_section_shared',
      };

  String get metadataValue => switch (this) {
        _HistorySection.recent => 'recent',
        _HistorySection.archived => 'archived',
        _HistorySection.shared => 'shared',
      };
}

class _HistorySectionState {
  const _HistorySectionState({
    this.threads = const [],
    this.cursor,
    this.hasMore = false,
    this.loadingInitial = false,
    this.loadingMore = false,
    this.initialized = false,
    this.error,
  });

  final List<ThreadMetadata> threads;
  final String? cursor;
  final bool hasMore;
  final bool loadingInitial;
  final bool loadingMore;
  final bool initialized;
  final String? error;

  static const Object _sentinel = Object();

  _HistorySectionState copyWith({
    List<ThreadMetadata>? threads,
    String? cursor,
    bool? hasMore,
    bool? loadingInitial,
    bool? loadingMore,
    bool? initialized,
    Object? error = _sentinel,
  }) {
    return _HistorySectionState(
      threads: threads ?? this.threads,
      cursor: cursor ?? this.cursor,
      hasMore: hasMore ?? this.hasMore,
      loadingInitial: loadingInitial ?? this.loadingInitial,
      loadingMore: loadingMore ?? this.loadingMore,
      initialized: initialized ?? this.initialized,
      error: identical(error, _sentinel) ? this.error : error as String?,
    );
  }
}

class _EntityBadge extends StatelessWidget {
  const _EntityBadge({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(left: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _AuthExpiredBanner extends StatelessWidget {
  const _AuthExpiredBanner({
    required this.localizations,
    required this.onDismiss,
  });

  final ChatKitLocalizations localizations;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      color: theme.colorScheme.errorContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  localizations.t('auth_expired'),
                  style: theme.textTheme.titleSmall
                      ?.copyWith(color: theme.colorScheme.onErrorContainer),
                ),
                const SizedBox(height: 4),
                Text(
                  localizations.t('auth_expired_description'),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onErrorContainer),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onDismiss,
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.onErrorContainer,
            ),
            child: Text(localizations.t('auth_expired_dismiss')),
          ),
        ],
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({required this.action});

  final HeaderActionOption action;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: action.onClick,
      icon: _iconForHeader(action.icon),
    );
  }

  Icon _iconForHeader(String icon) {
    switch (icon) {
      case HeaderIcons.sidebarLeft:
      case HeaderIcons.sidebarOpenLeft:
      case HeaderIcons.sidebarCollapseRight:
      case HeaderIcons.backSmall:
      case HeaderIcons.backLarge:
      case HeaderIcons.collapseLeft:
      case HeaderIcons.openLeft:
        return const Icon(Icons.arrow_back);
      case HeaderIcons.sidebarRight:
      case HeaderIcons.sidebarOpenRight:
      case HeaderIcons.sidebarCollapseLeft:
      case HeaderIcons.openRight:
      case HeaderIcons.doubleChevronRight:
        return const Icon(Icons.arrow_forward);
      case HeaderIcons.sidebarFloatingLeft:
      case HeaderIcons.sidebarFloatingOpenLeft:
        return const Icon(Icons.keyboard_double_arrow_left);
      case HeaderIcons.sidebarFloatingRight:
      case HeaderIcons.sidebarFloatingOpenRight:
        return const Icon(Icons.keyboard_double_arrow_right);
      case HeaderIcons.doubleChevronLeft:
        return const Icon(Icons.keyboard_double_arrow_left);
      case HeaderIcons.expandLarge:
      case HeaderIcons.expandSmall:
        return const Icon(Icons.open_in_full);
      case HeaderIcons.collapseLarge:
      case HeaderIcons.collapseSmall:
        return const Icon(Icons.close_fullscreen);
      case HeaderIcons.star:
        return const Icon(Icons.star_border);
      case HeaderIcons.starFilled:
        return const Icon(Icons.star);
      case HeaderIcons.chatTemporary:
        return const Icon(Icons.bolt);
      case HeaderIcons.settingsCog:
        return const Icon(Icons.settings);
      case HeaderIcons.grid:
        return const Icon(Icons.grid_view);
      case HeaderIcons.dotsHorizontal:
        return const Icon(Icons.more_horiz);
      case HeaderIcons.dotsVertical:
        return const Icon(Icons.more_vert);
      case HeaderIcons.dotsHorizontalCircle:
        return const Icon(Icons.more_horiz);
      case HeaderIcons.dotsVerticalCircle:
        return const Icon(Icons.more_vert);
      case HeaderIcons.menu:
      case HeaderIcons.hamburger:
      case HeaderIcons.menuInverted:
        return const Icon(Icons.menu);
      case HeaderIcons.compose:
      case HeaderIcons.add:
        return const Icon(Icons.add);
      case HeaderIcons.lightMode:
        return const Icon(Icons.light_mode);
      case HeaderIcons.darkMode:
        return const Icon(Icons.dark_mode);
      case HeaderIcons.close:
        return const Icon(Icons.close);
      default:
        switch (icon) {
          case 'bell':
            return const Icon(Icons.notifications);
          case 'check':
            return const Icon(Icons.check);
          case 'copy':
            return const Icon(Icons.copy);
          case 'delete':
            return const Icon(Icons.delete);
          case 'edit':
            return const Icon(Icons.edit);
          case 'refresh':
            return const Icon(Icons.refresh);
          case 'share':
            return const Icon(Icons.share);
          default:
            return const Icon(Icons.more_horiz);
        }
    }
  }
}

class _StartScreen extends StatelessWidget {
  const _StartScreen({this.options});

  final StartScreenOption? options;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              options?.greeting ?? 'What can I help with today?',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (options?.prompts case final prompts?)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final prompt in prompts)
                      ActionChip(
                        label: Text(prompt.label),
                        avatar: prompt.icon == null
                            ? null
                            : Icon(
                                _promptIconData(prompt.icon!),
                                size: 18,
                              ),
                        onPressed: () => _insertPrompt(context, prompt),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _insertPrompt(BuildContext context, StartScreenPrompt prompt) {
    final state = context.findAncestorStateOfType<_ChatKitViewState>();
    if (state == null) return;
    final composer = state._composerController;
    final text = prompt.prompt;
    composer.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    state.controller.setComposerValue(text: text);
  }

  IconData _promptIconData(String icon) {
    switch (icon) {
      case 'sparkle':
      case 'sparkle-double':
        return Icons.auto_awesome;
      case 'book-open':
      case 'book-closed':
        return Icons.menu_book_outlined;
      case 'lightbulb':
        return Icons.lightbulb_outline;
      case 'map-pin':
        return Icons.place_outlined;
      case 'profile':
      case 'profile-card':
        return Icons.person_outline;
      case 'analytics':
      case 'chart':
        return Icons.bar_chart_outlined;
      case 'write':
      case 'write-alt':
      case 'write-alt2':
        return Icons.edit_outlined;
      default:
        return Icons.chat_bubble_outline;
    }
  }
}

class _ChatItemView extends StatelessWidget {
  const _ChatItemView({
    super.key,
    required this.item,
    required this.controller,
    required this.localizations,
    this.actions,
  });

  final ThreadItem item;
  final ChatKitController controller;
  final ChatKitLocalizations localizations;
  final ThreadItemActionsOption? actions;

  @override
  Widget build(BuildContext context) {
    switch (item.type) {
      case 'user_message':
        return _UserMessageBubble(item: item);
      case 'assistant_message':
        return _AssistantMessageBubble(
          item: item,
          controller: controller,
          localizations: localizations,
          actions: actions,
        );
      case 'client_tool_call':
        return _ClientToolCallView(item: item);
      case 'widget':
        return _WidgetItemView(item: item, controller: controller);
      case 'workflow':
        return _WorkflowView(item: item);
      default:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text('Unsupported item type ${item.type}'),
        );
    }
  }
}

class _UserMessageBubble extends StatelessWidget {
  const _UserMessageBubble({required this.item});

  final ThreadItem item;

  @override
  Widget build(BuildContext context) {
    final text = item.content
        .where((entry) => entry['type'] == 'input_text')
        .map((entry) => entry['text'] as String? ?? '')
        .join('\n');
    final theme = Theme.of(context);
    final tokens = theme.extension<ChatKitThemeTokens>();
    final style = tokens?.userBubbleStyle;
    final background = style?.backgroundColor ?? theme.colorScheme.primary;
    final textColor = style?.textColor ?? theme.colorScheme.onPrimary;
    final borderColor = style?.borderColor;
    final radius = BorderRadius.circular(style?.radius ?? 12);
    final elevation = style?.elevation ?? 0;

    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        child: Material(
          elevation: elevation,
          color: background,
          borderRadius: radius,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: radius,
              border:
                  borderColor == null ? null : Border.all(color: borderColor),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                text,
                style: theme.textTheme.bodyMedium?.copyWith(color: textColor),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AssistantMessageBubble extends StatelessWidget {
  const _AssistantMessageBubble({
    required this.item,
    required this.controller,
    required this.localizations,
    this.actions,
  });

  final ThreadItem item;
  final ChatKitController controller;
  final ChatKitLocalizations localizations;
  final ThreadItemActionsOption? actions;

  @override
  Widget build(BuildContext context) {
    final textBuffer = StringBuffer();
    for (final part in item.content) {
      if (part['type'] == 'output_text') {
        textBuffer.writeln(part['text'] ?? '');
      }
    }
    final text = textBuffer.toString().trim();
    final theme = Theme.of(context);
    final tokens = theme.extension<ChatKitThemeTokens>();
    final style = tokens?.assistantBubbleStyle;
    final background =
        style?.backgroundColor ?? theme.colorScheme.surfaceContainerHighest;
    final textColor = style?.textColor ?? theme.textTheme.bodyMedium?.color;
    final borderColor = style?.borderColor;
    final radius = BorderRadius.circular(style?.radius ?? 12);
    final elevation = style?.elevation ?? 0;

    final bubble = Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        child: Material(
          elevation: elevation,
          color: background,
          borderRadius: radius,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: radius,
              border:
                  borderColor == null ? null : Border.all(color: borderColor),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: text.isEmpty
                  ? const SizedBox.shrink()
                  : MarkdownBody(
                      data: text,
                      styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                        p: theme.textTheme.bodyMedium?.copyWith(
                          color: textColor,
                        ),
                        strong: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );

    if (actions == null) {
      return bubble;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        bubble,
        _AssistantActionsBar(
          item: item,
          controller: controller,
          actions: actions!,
          localizations: localizations,
        ),
      ],
    );
  }
}

class _AssistantActionsBar extends StatefulWidget {
  const _AssistantActionsBar({
    required this.item,
    required this.controller,
    required this.actions,
    required this.localizations,
  });

  final ThreadItem item;
  final ChatKitController controller;
  final ThreadItemActionsOption actions;
  final ChatKitLocalizations localizations;

  @override
  State<_AssistantActionsBar> createState() => _AssistantActionsBarState();
}

class _AssistantActionsBarState extends State<_AssistantActionsBar> {
  bool _submitting = false;

  Future<void> _handleFeedback(String kind) async {
    setState(() => _submitting = true);
    try {
      await widget.controller.submitFeedback(
        threadId: widget.item.threadId,
        itemIds: [widget.item.id],
        kind: kind,
      );
      if (mounted) {
        final label = kind == 'positive'
            ? widget.localizations.t('feedback_positive')
            : widget.localizations.t('feedback_negative');
        final messenger = ScaffoldMessenger.maybeOf(context);
        final suppress = context
                .findAncestorStateOfType<_ChatKitViewState>()
                ?._suppressSnackbars ??
            false;
        if (!suppress && messenger != null) {
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                "${widget.localizations.t('feedback_sent')}: $label",
              ),
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _handleRetry() async {
    setState(() => _submitting = true);
    try {
      await widget.controller.retryAfterItem(
        threadId: widget.item.threadId,
        itemId: widget.item.id,
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  void _handleShare() {
    widget.controller.shareItem(widget.item.id);
  }

  @override
  Widget build(BuildContext context) {
    final actions = widget.actions;
    final l10n = widget.localizations;
    final buttons = <Widget>[];
    if (actions.feedback == true) {
      buttons.addAll([
        IconButton(
          tooltip: l10n.t('feedback_positive'),
          icon: const Icon(Icons.thumb_up_alt_outlined),
          onPressed: _submitting ? null : () => _handleFeedback('positive'),
        ),
        IconButton(
          tooltip: l10n.t('feedback_negative'),
          icon: const Icon(Icons.thumb_down_alt_outlined),
          onPressed: _submitting ? null : () => _handleFeedback('negative'),
        ),
      ]);
    }
    if (actions.retry == true) {
      buttons.add(
        IconButton(
          tooltip: l10n.t('retry_response'),
          icon: const Icon(Icons.refresh),
          onPressed: _submitting ? null : _handleRetry,
        ),
      );
    }
    if (actions.share == true) {
      buttons.add(
        IconButton(
          tooltip: l10n.t('share_message'),
          icon: const Icon(Icons.share),
          onPressed: _handleShare,
        ),
      );
    }

    if (buttons.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Row(children: buttons),
    );
  }
}

class _ClientToolCallView extends StatelessWidget {
  const _ClientToolCallView({required this.item});

  final ThreadItem item;

  @override
  Widget build(BuildContext context) {
    final name = item.raw['name'] as String? ?? 'Tool call';
    final status = item.raw['status'] as String? ?? 'pending';
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Client Tool: $name',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text('Status: $status'),
          ],
        ),
      ),
    );
  }
}

class _WidgetItemView extends StatelessWidget {
  const _WidgetItemView({
    required this.item,
    required this.controller,
  });

  final ThreadItem item;
  final ChatKitController controller;

  @override
  Widget build(BuildContext context) {
    final widgetJson = item.raw['widget'] as Map<String, Object?>?;
    if (widgetJson == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: ChatKitWidgetRenderer(
        widgetJson: widgetJson,
        controller: controller,
        item: item,
      ),
    );
  }
}

class _WorkflowView extends StatelessWidget {
  const _WorkflowView({required this.item});

  final ThreadItem item;

  @override
  Widget build(BuildContext context) {
    final workflow = item.raw['workflow'] as Map<String, Object?>?;
    if (workflow == null) {
      return const SizedBox.shrink();
    }
    final tasks =
        (workflow['tasks'] as List?)?.cast<Map<String, Object?>>() ?? const [];
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (workflow['summary'] is Map)
              Text(
                  'Workflow: ${(workflow['summary'] as Map)['title'] ?? 'Summary'}'),
            for (final task in tasks)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('- ${task['title'] ?? task['type']}'),
              ),
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.composerController,
    required this.focusNode,
    required this.onSend,
    required this.placeholder,
    required this.isStreaming,
    required this.onTextChanged,
    required this.localizations,
    this.isComposerLocked = false,
    this.lockMessage,
    this.onAttachment,
    this.attachments = const [],
    this.pendingUploads = const [],
    this.onRemoveAttachment,
    this.onAddTag,
    this.onRemoveTag,
    this.onTapTag,
    this.onPreviewTag,
    this.tags = const [],
    this.tools,
    this.models,
    this.selectedToolId,
    this.selectedModelId,
    this.onToolChanged,
    this.onModelChanged,
    this.onCancelUpload,
    this.onRetryUpload,
    this.onRemoveFailedUpload,
    required this.composerFieldLink,
    this.tagFocusNodes = const {},
    this.tagTooltipBuilder,
    this.tagAvatarBuilder,
  });

  final TextEditingController composerController;
  final FocusNode focusNode;
  final VoidCallback onSend;
  final VoidCallback? onAttachment;
  final String placeholder;
  final bool isStreaming;
  final bool isComposerLocked;
  final String? lockMessage;
  final ValueChanged<String> onTextChanged;
  final ChatKitLocalizations localizations;
  final List<ChatKitAttachment> attachments;
  final List<_PendingUpload> pendingUploads;
  final void Function(ChatKitAttachment attachment)? onRemoveAttachment;
  final void Function(_PendingUpload upload)? onCancelUpload;
  final void Function(_PendingUpload upload)? onRetryUpload;
  final void Function(_PendingUpload upload)? onRemoveFailedUpload;
  final VoidCallback? onAddTag;
  final void Function(Entity entity)? onRemoveTag;
  final void Function(Entity entity)? onTapTag;
  final Future<void> Function(Entity entity)? onPreviewTag;
  final List<Entity> tags;
  final List<ToolOption>? tools;
  final List<ModelOption>? models;
  final String? selectedToolId;
  final String? selectedModelId;
  final ValueChanged<String?>? onToolChanged;
  final ValueChanged<String?>? onModelChanged;
  final LayerLink composerFieldLink;
  final Map<String, FocusNode> tagFocusNodes;
  final String? Function(Entity entity)? tagTooltipBuilder;
  final Widget? Function(Entity entity)? tagAvatarBuilder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pinnedTools =
        tools?.where((tool) => tool.pinned).toList() ?? const [];
    final disabled = isStreaming || isComposerLocked;

    final tokens = Theme.of(context).extension<ChatKitThemeTokens>();
    final composerTokens = tokens?.composerStyle;
    final composerBackground =
        composerTokens?.backgroundColor ?? theme.colorScheme.surface;
    final composerTextColor = composerTokens?.textColor;
    final composerBorderColor = composerTokens?.borderColor;
    final composerRadius = composerTokens?.radius ?? 16;
    final composerElevation = composerTokens?.elevation ?? 0;

    Widget content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (pinnedTools.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Wrap(
              spacing: 8,
              children: [
                for (final tool in pinnedTools)
                  FilterChip(
                    label: Text(tool.shortLabel ?? tool.label),
                    avatar: _iconForTool(tool.icon),
                    selected: selectedToolId == tool.id,
                    onSelected: disabled
                        ? null
                        : (value) {
                            if (onToolChanged == null) return;
                            if (value) {
                              onToolChanged!(tool.id);
                            } else {
                              onToolChanged!(null);
                            }
                          },
                  ),
              ],
            ),
          ),
        if (tags.isNotEmpty || onAddTag != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final tag in tags)
                  Builder(
                    builder: (context) {
                      final tooltip = tagTooltipBuilder?.call(tag);
                      final avatar = tagAvatarBuilder?.call(tag);
                      Widget chip = InputChip(
                        label: Text(tag.title),
                        focusNode: tagFocusNodes[tag.id],
                        avatar: avatar,
                        onPressed: disabled || onTapTag == null
                            ? null
                            : () => onTapTag!(tag),
                        onDeleted: disabled || onRemoveTag == null
                            ? null
                            : () => onRemoveTag!(tag),
                      );
                      if (tooltip != null && tooltip.isNotEmpty) {
                        chip = Tooltip(
                          message: tooltip,
                          waitDuration: const Duration(milliseconds: 400),
                          child: chip,
                        );
                      }
                      return GestureDetector(
                        onLongPress: onPreviewTag == null
                            ? null
                            : () => onPreviewTag!(tag),
                        child: chip,
                      );
                    },
                  ),
                if (onAddTag != null)
                  ActionChip(
                    label: Text(localizations.t('composer_add_tag')),
                    avatar: const Icon(Icons.alternate_email, size: 18),
                    onPressed: disabled ? null : onAddTag,
                  ),
              ],
            ),
          ),
        if ((models != null && models!.isNotEmpty) ||
            (tools != null && tools!.isNotEmpty))
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                if (models != null && models!.isNotEmpty)
                  SizedBox(
                    width: 180,
                    child: DropdownButtonFormField<String?>(
                      initialValue: selectedModelId,
                      decoration: InputDecoration(
                        labelText: localizations.t('composer_model_label'),
                      ),
                      items: [
                        for (final model in models!)
                          DropdownMenuItem<String?>(
                            value: model.id,
                            enabled: !model.disabled,
                            child: Text(
                              model.label,
                              style: model.disabled
                                  ? theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.disabledColor,
                                    )
                                  : null,
                            ),
                          ),
                      ],
                      onChanged: disabled ? null : onModelChanged,
                    ),
                  ),
                if (tools != null && tools!.isNotEmpty)
                  SizedBox(
                    width: 180,
                    child: DropdownButtonFormField<String?>(
                      initialValue: selectedToolId,
                      decoration: InputDecoration(
                        labelText: localizations.t('composer_tool_label'),
                      ),
                      items: [
                        DropdownMenuItem<String?>(
                          value: null,
                          child: Text(localizations.t('composer_tool_auto')),
                        ),
                        for (final tool in tools!)
                          DropdownMenuItem<String?>(
                            value: tool.id,
                            child: Text(tool.shortLabel ?? tool.label),
                          ),
                      ],
                      onChanged: disabled ? null : onToolChanged,
                    ),
                  ),
              ],
            ),
          ),
        if (pendingUploads.isNotEmpty || attachments.isNotEmpty)
          SizedBox(
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              itemCount: pendingUploads.length + attachments.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                if (index < pendingUploads.length) {
                  final upload = pendingUploads[index];
                  return _AttachmentUploadChip(
                    upload: upload,
                    localizations: localizations,
                    onCancel: onCancelUpload == null
                        ? null
                        : () => onCancelUpload!(upload),
                    onRetry: onRetryUpload == null
                        ? null
                        : () => onRetryUpload!(upload),
                    onRemove: onRemoveFailedUpload == null
                        ? null
                        : () => onRemoveFailedUpload!(upload),
                  );
                }
                final attachment = attachments[index - pendingUploads.length];
                return _AttachmentChip(
                  attachment: attachment,
                  onRemove: onRemoveAttachment,
                );
              },
            ),
          ),
        if (isComposerLocked && lockMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                lockMessage!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        Row(
          children: [
            if (onAttachment != null)
              IconButton(
                icon: const Icon(Icons.attach_file),
                onPressed: disabled ? null : onAttachment,
              ),
            if (onAddTag != null)
              IconButton(
                icon: const Icon(Icons.alternate_email),
                tooltip: localizations.t('composer_add_tag'),
                onPressed: disabled ? null : onAddTag,
              ),
            Expanded(
              child: CompositedTransformTarget(
                link: composerFieldLink,
                child: TextField(
                  controller: composerController,
                  focusNode: focusNode,
                  minLines: 1,
                  maxLines: 5,
                  enabled: !disabled,
                  decoration: InputDecoration(
                    hintText: placeholder,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: onTextChanged,
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: disabled ? null : onSend,
              child: isStreaming
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.colorScheme.onPrimary,
                      ),
                    )
                  : isComposerLocked
                      ? const Icon(Icons.lock_outline)
                      : const Icon(Icons.send),
            ),
          ],
        ),
      ],
    );

    if (composerTextColor != null) {
      content = IconTheme.merge(
        data: IconThemeData(color: composerTextColor),
        child: DefaultTextStyle.merge(
          style: theme.textTheme.bodyMedium?.copyWith(
            color: composerTextColor,
          ),
          child: content,
        ),
      );
    }

    return SafeArea(
      top: false,
      child: Material(
        elevation: composerElevation,
        color: composerBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(composerRadius),
          side: composerBorderColor == null
              ? BorderSide.none
              : BorderSide(color: composerBorderColor),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: content,
        ),
      ),
    );
  }

  Widget? _iconForTool(String? iconName) {
    if (iconName == null) {
      return null;
    }
    switch (iconName) {
      case 'browser':
      case 'search':
        return const Icon(Icons.public, size: 18);
      case 'calendar':
        return const Icon(Icons.calendar_today, size: 18);
      case 'email':
        return const Icon(Icons.email, size: 18);
      case 'calculator':
        return const Icon(Icons.calculate, size: 18);
      default:
        return const Icon(Icons.extension, size: 18);
    }
  }
}

class _AttachmentPayload {
  const _AttachmentPayload({
    required this.name,
    required this.bytes,
    required this.mimeType,
    required this.size,
  });

  final String name;
  final Uint8List bytes;
  final String mimeType;
  final int size;
}

enum _RejectionType { type, size, limit }

class _FileRejection {
  const _FileRejection({
    required this.name,
    required this.type,
    this.detail,
  });

  final String name;
  final _RejectionType type;
  final String? detail;
}

class _PendingUpload {
  _PendingUpload({
    required this.id,
    required this.name,
    required this.mimeType,
    required this.size,
    required this.bytes,
  }) : total = size;

  final String id;
  final String name;
  final String mimeType;
  final int size;
  final Uint8List bytes;

  int total;
  int sent = 0;
  bool cancelled = false;
  Object? error;
  bool inFlight = false;

  double? get progress => total <= 0 ? null : (sent / total).clamp(0, 1);

  bool get hasError => error != null;
}

class _BannerMessage {
  const _BannerMessage({
    required this.id,
    required this.message,
    required this.level,
    this.title,
    this.code,
    this.retryAt,
  });

  final String id;
  final String message;
  final ChatKitNoticeLevel level;
  final String? title;
  final String? code;
  final DateTime? retryAt;

  _BannerMessage copyWith({
    String? message,
    ChatKitNoticeLevel? level,
    String? title,
    String? code,
    DateTime? retryAt,
  }) {
    return _BannerMessage(
      id: id,
      message: message ?? this.message,
      level: level ?? this.level,
      title: title ?? this.title,
      code: code ?? this.code,
      retryAt: retryAt ?? this.retryAt,
    );
  }
}

class _NoticeBanner extends StatelessWidget {
  const _NoticeBanner({
    required this.banner,
    required this.localizations,
    required this.onClose,
  });

  final _BannerMessage banner;
  final ChatKitLocalizations localizations;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = _paletteForLevel(theme, banner.level);
    return Material(
      color: palette.background,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(palette.icon, color: palette.iconColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (banner.title != null && banner.title!.isNotEmpty)
                    Text(
                      banner.title!,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: palette.foreground,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  Text(
                    banner.message,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: palette.foreground,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              color: palette.iconColor,
              tooltip: localizations.t('banner_dismiss'),
              onPressed: onClose,
            ),
          ],
        ),
      ),
    );
  }

  _NoticePalette _paletteForLevel(ThemeData theme, ChatKitNoticeLevel level) {
    switch (level) {
      case ChatKitNoticeLevel.warning:
        return _NoticePalette(
          background: theme.colorScheme.tertiaryContainer,
          foreground: theme.colorScheme.onTertiaryContainer,
          icon: Icons.warning_amber_rounded,
          iconColor: theme.colorScheme.onTertiaryContainer,
        );
      case ChatKitNoticeLevel.error:
        return _NoticePalette(
          background: theme.colorScheme.errorContainer,
          foreground: theme.colorScheme.onErrorContainer,
          icon: Icons.error_outline,
          iconColor: theme.colorScheme.onErrorContainer,
        );
      case ChatKitNoticeLevel.info:
        return _NoticePalette(
          background: theme.colorScheme.surfaceContainerHighest,
          foreground: theme.colorScheme.onSurface,
          icon: Icons.info_outline,
          iconColor: theme.colorScheme.primary,
        );
    }
  }
}

class _NoticePalette {
  const _NoticePalette({
    required this.background,
    required this.foreground,
    required this.icon,
    required this.iconColor,
  });

  final Color background;
  final Color foreground;
  final IconData icon;
  final Color iconColor;
}

enum _LayoutSize { compact, medium, expanded }

class _AttachmentChip extends StatelessWidget {
  const _AttachmentChip({
    required this.attachment,
    this.onRemove,
  });

  final ChatKitAttachment attachment;
  final void Function(ChatKitAttachment attachment)? onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isImage = attachment is ImageAttachment;
    final typeLabel =
        _attachmentTypeLabel(attachment.name, attachment.mimeType);
    final metadata = _attachmentMetadata(attachment);
    final preview = isImage
        ? CachedNetworkImage(
            imageUrl: (attachment as ImageAttachment).previewUrl,
            fit: BoxFit.cover,
          )
        : Container(
            color: theme.colorScheme.surfaceContainerHighest,
            alignment: Alignment.center,
            child: Icon(
              _iconForMimeType(attachment.mimeType),
              size: 32,
              color: theme.colorScheme.primary,
            ),
          );

    final removeTooltip = MaterialLocalizations.of(context).deleteButtonTooltip;

    return Container(
      width: 140,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(child: preview),
          if (typeLabel != null)
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isImage
                      ? Colors.black54
                      : theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  typeLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: isImage
                        ? Colors.white
                        : theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          if (onRemove != null)
            Positioned(
              top: 6,
              right: 6,
              child: Tooltip(
                message: removeTooltip,
                child: InkWell(
                  onTap: () => onRemove!(attachment),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                    padding: const EdgeInsets.all(4),
                    child:
                        const Icon(Icons.close, size: 16, color: Colors.white),
                  ),
                ),
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: isImage
                    ? Colors.black.withValues(alpha: 0.55)
                    : theme.colorScheme.surface,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    attachment.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color:
                          isImage ? Colors.white : theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (metadata != null)
                    Text(
                      metadata,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: isImage
                            ? Colors.white70
                            : theme.colorScheme.onSurfaceVariant,
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

class _AttachmentUploadChip extends StatelessWidget {
  const _AttachmentUploadChip({
    required this.upload,
    required this.localizations,
    this.onCancel,
    this.onRetry,
    this.onRemove,
  });

  final _PendingUpload upload;
  final ChatKitLocalizations localizations;
  final VoidCallback? onCancel;
  final VoidCallback? onRetry;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final String? sizeLabel =
        upload.size > 0 ? _formatBytes(upload.size) : null;
    final typeLabel = _attachmentTypeLabel(upload.name, upload.mimeType);

    if (upload.hasError) {
      return SizedBox(
        width: 180,
        child: Material(
          elevation: 1,
          color: theme.colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(Icons.error_outline, color: theme.colorScheme.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        upload.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onErrorContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                if (typeLabel != null || sizeLabel != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      [
                        if (typeLabel != null) typeLabel,
                        if (sizeLabel != null) sizeLabel,
                      ].where((element) => element.isNotEmpty).join(' • '),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onErrorContainer
                            .withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    localizations.t('attachment_upload_failed'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  ),
                ),
                if (onRetry != null || onRemove != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Wrap(
                      spacing: 8,
                      children: [
                        if (onRetry != null)
                          TextButton(
                            onPressed: onRetry,
                            child: Text(
                              localizations.t('attachment_retry_upload'),
                            ),
                          ),
                        if (onRemove != null)
                          TextButton(
                            onPressed: onRemove,
                            child: Text(localizations.t('attachment_remove')),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    final progress = upload.progress;
    final percentage = progress != null
        ? '${(progress * 100).clamp(0, 100).toStringAsFixed(0)}%'
        : null;
    String? transferred;
    if (progress != null && upload.total > 0) {
      transferred =
          '${_formatBytes(upload.sent)} / ${_formatBytes(upload.total)}';
    }
    final statusParts = <String>[];
    if (percentage != null) {
      statusParts.add(percentage);
    }
    if (transferred != null) {
      statusParts.add(transferred);
    }
    if (statusParts.isEmpty) {
      statusParts.add('…');
    }
    final statusText =
        '${localizations.t('attachment_uploading')} ${statusParts.join(' • ')}';
    final details = [
      if (typeLabel != null) typeLabel,
      if (sizeLabel != null) sizeLabel,
    ].where((element) => element.isNotEmpty).join(' • ');
    final cancelEnabled =
        onCancel != null && upload.inFlight && !upload.cancelled;

    return SizedBox(
      width: 180,
      child: Material(
        elevation: 1,
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      upload.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (details.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(
                        details,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  if (cancelEnabled)
                    Tooltip(
                      message: localizations.t('attachment_cancel_upload'),
                      child: IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(
                          width: 28,
                          height: 28,
                        ),
                        onPressed: onCancel,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(value: progress),
              const SizedBox(height: 8),
              Text(
                statusText,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String? _attachmentTypeLabel(String name, String mimeType) {
  final extension = _extensionFromName(name);
  if (extension != null && extension.isNotEmpty) {
    return extension;
  }
  final lower = mimeType.toLowerCase();
  final slashIndex = lower.indexOf('/');
  if (slashIndex != -1 && slashIndex < lower.length - 1) {
    final subtype = lower.substring(slashIndex + 1);
    if (subtype != '*') {
      return subtype.toUpperCase();
    }
  }
  return null;
}

String? _attachmentMetadata(ChatKitAttachment attachment) {
  final size = attachment.size;
  if (size != null && size > 0) {
    return _formatBytes(size);
  }
  return null;
}

IconData _iconForMimeType(String mimeType) {
  final lower = mimeType.toLowerCase();
  if (lower.startsWith('image/')) {
    return Icons.image_outlined;
  }
  if (lower.startsWith('video/')) {
    return Icons.movie_creation_outlined;
  }
  if (lower.startsWith('audio/')) {
    return Icons.audiotrack;
  }
  if (lower.contains('pdf')) {
    return Icons.picture_as_pdf;
  }
  if (lower.contains('zip') || lower.contains('compressed')) {
    return Icons.archive_outlined;
  }
  if (lower.startsWith('text/')) {
    return Icons.description_outlined;
  }
  if (lower.contains('presentation') ||
      lower.endsWith('ppt') ||
      lower.endsWith('pptx')) {
    return Icons.slideshow;
  }
  if (lower.contains('sheet') ||
      lower.endsWith('xls') ||
      lower.endsWith('xlsx')) {
    return Icons.table_chart_outlined;
  }
  return Icons.insert_drive_file;
}

String? _extensionFromName(String name) {
  final trimmed = name.trim();
  final dotIndex = trimmed.lastIndexOf('.');
  if (dotIndex <= 0 || dotIndex == trimmed.length - 1) {
    return null;
  }
  final ext = trimmed.substring(dotIndex + 1);
  if (ext.isEmpty) {
    return null;
  }
  return ext.toUpperCase();
}

String _formatBytes(int bytes) {
  if (bytes < 1024) {
    return '$bytes B';
  }
  const units = ['KB', 'MB', 'GB', 'TB'];
  var value = bytes / 1024;
  var unitIndex = 0;
  while (value >= 1024 && unitIndex < units.length - 1) {
    value /= 1024;
    unitIndex++;
  }
  final formatted =
      value >= 10 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
  return '$formatted ${units[unitIndex]}';
}

ChatKitAttachment _ensureAttachmentSize(
  ChatKitAttachment attachment,
  int size,
) {
  if (size <= 0 || attachment.size != null) {
    return attachment;
  }
  if (attachment is ImageAttachment) {
    return ImageAttachment(
      id: attachment.id,
      name: attachment.name,
      mimeType: attachment.mimeType,
      previewUrl: attachment.previewUrl,
      uploadUrl: attachment.uploadUrl,
      size: size,
    );
  }
  if (attachment is FileAttachment) {
    return FileAttachment(
      id: attachment.id,
      name: attachment.name,
      mimeType: attachment.mimeType,
      uploadUrl: attachment.uploadUrl,
      size: size,
    );
  }
  return attachment;
}
