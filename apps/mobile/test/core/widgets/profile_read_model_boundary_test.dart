import 'dart:io';
import 'package:dailio/core/storage/json_cache_store.dart';
import 'package:dailio/core/widgets/profile_read_model_boundary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _Probe extends StatefulWidget {
  const _Probe(this.onMount);
  final VoidCallback onMount;
  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  @override
  void initState() {
    super.initState();
    widget.onMount();
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

void main() {
  testWidgets(
      'read pages reload after profile edits but stay mounted during ordinary cache writes',
      (tester) async {
    final root = (await tester
        .runAsync(() => Directory.systemTemp.createTemp('profile-boundary-')))!;
    final cache = JsonCacheStore(directoryProvider: () async => root);
    var mounts = 0;
    try {
      await tester.pumpWidget(ChangeNotifierProvider.value(
          value: cache,
          child: MaterialApp(
              home: ProfileReadModelBoundary(child: _Probe(() => mounts++)))));
      expect(mounts, 1);
      await tester.runAsync(
          () => cache.write('ordinary', {'value': 1}, scope: 'branch'));
      await tester.pump();
      expect(mounts, 1);
      await tester.runAsync(() => cache.invalidateProfiles());
      await tester.pump();
      expect(mounts, 2);
      await tester.pumpWidget(const SizedBox());
    } finally {
      cache.dispose();
      await tester.runAsync(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });
    }
  });
}
