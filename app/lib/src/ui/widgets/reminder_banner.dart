import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/reminder_notice.dart';
import '../theme.dart';

/// A persistent top-of-shell banner shown while **no** timer is running and the
/// "track your time" reminder is due. Unlike the old OS-notification/SnackBar
/// pair it stays on screen until a timer starts (cleared via
/// [reminderNoticeProvider]). Message-only — no buttons. Mirrors the chrome of
/// [ReleaseUpdateBanner].
class ReminderBanner extends ConsumerWidget {
  const ReminderBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notice = ref.watch(reminderNoticeProvider);
    if (!notice.visible) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).extension<RedtickTokens>()!;

    return Material(
      color: t.accentSoft,
      child: SafeArea(
        bottom: false,
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: t.hairline)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Icon(Icons.timer_off_outlined, size: 18, color: cs.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  notice.body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
