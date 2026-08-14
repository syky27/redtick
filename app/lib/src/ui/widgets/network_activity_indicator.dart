import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';

/// Thin, non-blocking top progress bar shown while user-initiated Redmine
/// requests are in flight (mobile surface; desktop shows the same state in the
/// sidebar instance chip). Overlaid via a `Stack`, so it never shifts layout,
/// and wrapped in [IgnorePointer] so it never blocks input.
class NetworkActivityBar extends ConsumerWidget {
  const NetworkActivityBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy = ref.watch(networkActivityProvider).asData?.value ?? false;
    final cs = Theme.of(context).colorScheme;
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: busy ? 1 : 0,
        duration: const Duration(milliseconds: 150),
        child: busy
            ? LinearProgressIndicator(
                minHeight: 2,
                color: cs.primary,
                backgroundColor: Colors.transparent,
              )
            : const SizedBox(height: 2),
      ),
    );
  }
}
