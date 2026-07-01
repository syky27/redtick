import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/redmine_service.dart';
import '../../state/providers.dart';
import '../theme.dart';
import 'entry_bits.dart';

/// Opens the issue picker (design §3.7) and returns the chosen issue, or null.
Future<IssueResult?> showIssuePicker(BuildContext context) {
  return showDialog<IssueResult>(
    context: context,
    builder: (_) => const _IssuePickerDialog(),
  );
}

class _IssuePickerDialog extends ConsumerStatefulWidget {
  const _IssuePickerDialog();

  @override
  ConsumerState<_IssuePickerDialog> createState() => _IssuePickerDialogState();
}

class _IssuePickerDialogState extends ConsumerState<_IssuePickerDialog> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  IssueScope _scope = IssueScope.mine;
  List<IssueResult> _results = const [];
  List<GlobalKey> _rowKeys = const [];
  int _selected = 0;
  bool _loading = true;
  Timer? _debounce;
  int _reqId = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onQuery(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _load);
  }

  Future<void> _load() async {
    final id = ++_reqId;
    setState(() => _loading = true);
    final query = _search.text.trim();
    final svc = ref.read(coreServiceProvider);
    var scope = _scope;
    var res = await svc.searchIssues(query: query, scope: scope);
    if (!mounted || id != _reqId) return;
    // Broaden narrow scopes (mine / assigned) → all when a typed query finds
    // nothing, so the user still lands on the issue they're searching for.
    if (res.isEmpty && query.isNotEmpty && scope != IssueScope.all) {
      scope = IssueScope.all;
      res = await svc.searchIssues(query: query, scope: scope);
      if (!mounted || id != _reqId) return;
    }
    setState(() {
      _scope = scope;
      _results = res;
      _rowKeys = List.generate(res.length, (_) => GlobalKey());
      _selected = 0;
      _loading = false;
    });
  }

  void _setScope(IssueScope s) {
    if (s == _scope) return;
    setState(() => _scope = s);
    _load();
  }

  void _move(int delta) {
    if (_results.isEmpty) return;
    setState(() => _selected = (_selected + delta).clamp(0, _results.length - 1));
    final ctx = _rowKeys[_selected].currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx,
          alignment: 0.5, duration: const Duration(milliseconds: 120));
    }
  }

  void _confirm() {
    if (_results.isEmpty) return;
    Navigator.of(context).pop(_results[_selected]);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).extension<RedtickTokens>()!;
    // ↵/↑↓/esc navigation is a physical-keyboard affordance: desktop only.
    final isDesktop =
        Platform.isMacOS || Platform.isWindows || Platform.isLinux;
    final dialog = Dialog(
      backgroundColor: cs.surface,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                controller: _search,
                autofocus: true,
                onChanged: _onQuery,
                onSubmitted: isDesktop ? (_) => _confirm() : null,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search, size: 18),
                  hintText: '#num or text',
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _SegBtn('My issues', _scope == IssueScope.mine,
                        () => _setScope(IssueScope.mine)),
                    _SegBtn('Assigned', _scope == IssueScope.assigned,
                        () => _setScope(IssueScope.assigned)),
                    _SegBtn('All visible', _scope == IssueScope.all,
                        () => _setScope(IssueScope.all)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Divider(height: 1, color: t.hairline),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _results.isEmpty
                      ? Center(
                          child: Text('No issues',
                              style: TextStyle(color: cs.onSurfaceVariant)))
                      : ListView.separated(
                          controller: _scroll,
                          itemCount: _results.length,
                          separatorBuilder: (_, _) =>
                              Divider(height: 1, color: t.hairline),
                          itemBuilder: (context, i) => _Row(
                            key: _rowKeys[i],
                            issue: _results[i],
                            selected: isDesktop && i == _selected,
                            onHover: isDesktop
                                ? () {
                                    if (_selected != i) {
                                      setState(() => _selected = i);
                                    }
                                  }
                                : null,
                          ),
                        ),
            ),
            if (isDesktop) ...[
              Divider(height: 1, color: t.hairline),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    _Hint('↵', 'Start timer'),
                    const SizedBox(width: 16),
                    _Hint('↑↓', 'Navigate'),
                    const Spacer(),
                    _Hint('esc', 'Close'),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
    if (!isDesktop) return dialog;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowDown): () => _move(1),
        const SingleActivator(LogicalKeyboardKey.arrowUp): () => _move(-1),
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).pop(),
      },
      child: dialog,
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    super.key,
    required this.issue,
    this.selected = false,
    this.onHover,
  });
  final IssueResult issue;
  final bool selected;
  final VoidCallback? onHover;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).extension<RedtickTokens>()!;
    final dot = projectColorForId(issue.projectId);
    return InkWell(
      onTap: () => Navigator.of(context).pop(issue),
      onHover: onHover == null
          ? null
          : (h) {
              if (h) onHover!();
            },
      child: Container(
        color: selected ? t.accentSoft : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(issue.subject,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13.5)),
                  const SizedBox(height: 2),
                  Text('#${issue.id} · ${issue.projectName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            _StatusBadge(name: issue.statusName, closed: issue.closed),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.name, required this.closed});
  final String name;
  final bool closed;

  @override
  Widget build(BuildContext context) {
    if (name.isEmpty) return const SizedBox.shrink();
    final c = _color(name, closed);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(name,
          style: TextStyle(
              color: c, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  static Color _color(String name, bool closed) {
    final n = name.toLowerCase();
    if (closed || n.contains('closed') || n.contains('rejected')) {
      return const Color(0xFF16A34A);
    }
    if (n.contains('progress')) return const Color(0xFFF59E0B);
    if (n.contains('feedback')) return const Color(0xFF8B5CF6);
    if (n.contains('resolved')) return const Color(0xFF0D9488);
    return const Color(0xFF3B82F6); // New / default
  }
}

class _SegBtn extends StatelessWidget {
  const _SegBtn(this.label, this.selected, this.onTap);
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).extension<RedtickTokens>()!;
    return Material(
      color: selected ? t.accentSoft : Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(label,
              style: TextStyle(
                  color: selected ? cs.primary : cs.onSurfaceVariant,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 12.5)),
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.key_, this.label);
  final String key_;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).extension<RedtickTokens>()!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: t.hairline),
          ),
          child: Text(key_,
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
        ),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 11, color: t.faint)),
      ],
    );
  }
}
