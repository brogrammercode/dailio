import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../storage/json_cache_store.dart';

/// Refresh read pages after a profile edit without remounting editor routes.
class ProfileReadModelBoundary extends StatelessWidget {
  const ProfileReadModelBoundary({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final revision =
        context.select<JsonCacheStore, int>((cache) => cache.profileRevision);
    return KeyedSubtree(key: ValueKey(revision), child: child);
  }
}
