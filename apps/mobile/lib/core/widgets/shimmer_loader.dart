import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class ShimmerLoader extends StatelessWidget {
  const ShimmerLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: const SkeletonList(),
    );
  }

  static Widget list() => const ShimmerLoader();

  /// Loading state for compact list pages such as fees and payments.
  /// The geometry mirrors [DailioCompactTile] so the list does not jump when
  /// the server response arrives.
  static Widget compactList() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: ListView.separated(
        padding: const EdgeInsets.only(top: 12, bottom: 96),
        itemCount: 6,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, __) => const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            height: 68,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(radius: 24, backgroundColor: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 150,
                        height: 14,
                        child: ColoredBox(color: Colors.white),
                      ),
                      SizedBox(height: 8),
                      SizedBox(
                        width: 210,
                        height: 11,
                        child: ColoredBox(color: Colors.white),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 12),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    SizedBox(
                      width: 54,
                      height: 11,
                      child: ColoredBox(color: Colors.white),
                    ),
                    SizedBox(height: 9),
                    SizedBox(
                      width: 18,
                      height: 4,
                      child: ColoredBox(color: Colors.white),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget form() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: ListView.separated(
        padding: const EdgeInsets.all(24),
        itemCount: 5,
        separatorBuilder: (_, __) => const SizedBox(height: 24),
        itemBuilder: (_, __) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(width: 120, height: 16, color: Colors.white),
            const SizedBox(height: 10),
            Container(
                width: double.infinity,
                height: 50,
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10))),
          ],
        ),
      ),
    );
  }

  static Widget cards() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: ListView.separated(
        padding: const EdgeInsets.all(24),
        itemCount: 4,
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemBuilder: (_, __) => Container(
          width: double.infinity,
          height: 100,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  /// Skeleton for compact management rows: icon/avatar, two text lines and
  /// a right-side status/action placeholder.
  static Widget settingsList({int count = 6}) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        itemCount: count,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, __) => Container(
          height: 68,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              const SizedBox(
                width: 38,
                height: 38,
                child: ColoredBox(color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    SizedBox(
                        width: 150,
                        height: 13,
                        child: ColoredBox(color: Colors.white)),
                    SizedBox(height: 8),
                    SizedBox(
                        width: 210,
                        height: 10,
                        child: ColoredBox(color: Colors.white)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const SizedBox(
                  width: 34,
                  height: 12,
                  child: ColoredBox(color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }

  /// Skeleton matching settings forms after the shared Dailio app bar.
  static Widget settingsForm({bool withAvatar = false}) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          if (withAvatar) ...[
            const Center(
              child: SizedBox(
                  width: 76,
                  height: 76,
                  child: ColoredBox(color: Colors.white)),
            ),
            const SizedBox(height: 22),
          ],
          ...List.generate(
            5,
            (_) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  SizedBox(
                      width: 120,
                      height: 11,
                      child: ColoredBox(color: Colors.white)),
                  SizedBox(height: 7),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ColoredBox(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Skeleton for the compact plan editor. The branch selector is rendered by
  /// [BranchFilterTabs], so this starts with plan tabs and mirrors the form.
  static Widget planEditor() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: List.generate(
                    3,
                    (index) => Padding(
                      padding: EdgeInsets.only(right: index == 2 ? 0 : 12),
                      child: const SizedBox(
                        width: 64,
                        height: 18,
                        child: ColoredBox(color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(
                  width: 24,
                  height: 24,
                  child: ColoredBox(color: Colors.white)),
            ],
          ),
          const SizedBox(height: 20),
          const SizedBox(
              width: 110, height: 16, child: ColoredBox(color: Colors.white)),
          const SizedBox(height: 16),
          ...List.generate(
            5,
            (index) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(
                      width: 92,
                      height: 11,
                      child: ColoredBox(color: Colors.white)),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: index == 4 ? 44 : 48,
                    child: ColoredBox(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget planList() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 30),
        children: [
          const SizedBox(
              width: 130, height: 22, child: ColoredBox(color: Colors.white)),
          const SizedBox(height: 7),
          const SizedBox(
              width: 250, height: 12, child: ColoredBox(color: Colors.white)),
          const SizedBox(height: 20),
          ...List.generate(
            4,
            (_) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child:
                  SizedBox(height: 58, child: ColoredBox(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  static Widget detailPage() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Row(
            children: const [
              CircleAvatar(radius: 25, backgroundColor: Colors.white),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                        width: 160,
                        height: 16,
                        child: ColoredBox(color: Colors.white)),
                    SizedBox(height: 7),
                    SizedBox(
                        width: 110,
                        height: 11,
                        child: ColoredBox(color: Colors.white)),
                  ],
                ),
              ),
              SizedBox(
                  width: 64,
                  height: 22,
                  child: ColoredBox(color: Colors.white)),
            ],
          ),
          const SizedBox(height: 26),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SizedBox(
                  width: 120,
                  height: 30,
                  child: ColoredBox(color: Colors.white)),
              SizedBox(
                  width: 90,
                  height: 24,
                  child: ColoredBox(color: Colors.white)),
            ],
          ),
          const SizedBox(height: 22),
          ...List.generate(
            4,
            (_) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child:
                  SizedBox(height: 92, child: ColoredBox(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  static Widget selfAttendance() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        children: [
          const Center(
              child: SizedBox(
                  width: 140,
                  height: 28,
                  child: ColoredBox(color: Colors.white))),
          const SizedBox(height: 8),
          const Center(
              child: SizedBox(
                  width: 170,
                  height: 12,
                  child: ColoredBox(color: Colors.white))),
          const SizedBox(height: 28),
          const Center(
              child: SizedBox(
                  width: 220,
                  height: 220,
                  child: DecoratedBox(
                      decoration: BoxDecoration(
                          color: Colors.white, shape: BoxShape.circle)))),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(
              3,
              (_) => const SizedBox(
                  width: 70,
                  height: 42,
                  child: ColoredBox(color: Colors.white)),
            ),
          ),
          const SizedBox(height: 24),
          const SizedBox(height: 150, child: ColoredBox(color: Colors.white)),
        ],
      ),
    );
  }

  /// Skeleton for member directory screens with tabs, search and compact rows.
  static Widget directory() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 44, child: ColoredBox(color: Colors.white)),
            const SizedBox(height: 10),
            const SizedBox(height: 42, child: ColoredBox(color: Colors.white)),
            const SizedBox(height: 14),
            ...List.generate(
              6,
              (_) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SizedBox(
                    height: 68, child: ColoredBox(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Full loading layout for the roles page: branch tabs, role tabs, role
  /// summary, and permission groups.
  static Widget rolesPermissions() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(0, 12, 0, 120),
        children: [
          _tabStripSkeleton(count: 3, width: 62),
          const SizedBox(height: 10),
          _tabStripSkeleton(count: 3, width: 72),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  height: 54,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: const [
                      SizedBox(
                          width: 32,
                          height: 32,
                          child: ColoredBox(color: Colors.white)),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                                width: 130,
                                height: 13,
                                child: ColoredBox(color: Colors.white)),
                            SizedBox(height: 7),
                            SizedBox(
                                width: 190,
                                height: 10,
                                child: ColoredBox(color: Colors.white)),
                          ],
                        ),
                      ),
                      SizedBox(
                          width: 62,
                          height: 22,
                          child: ColoredBox(color: Colors.white)),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                ...List.generate(
                  3,
                  (_) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: const [
                            SizedBox(
                                width: 30,
                                height: 30,
                                child: ColoredBox(color: Colors.white)),
                            SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                      width: 150,
                                      height: 13,
                                      child: ColoredBox(color: Colors.white)),
                                  SizedBox(height: 6),
                                  SizedBox(
                                      width: 220,
                                      height: 10,
                                      child: ColoredBox(color: Colors.white)),
                                ],
                              ),
                            ),
                            SizedBox(
                                width: 54,
                                height: 20,
                                child: ColoredBox(color: Colors.white)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...List.generate(
                          3,
                          (_) => const Padding(
                            padding: EdgeInsets.only(bottom: 8),
                            child: SizedBox(
                                height: 38,
                                child: ColoredBox(color: Colors.white)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  /// Full loading layout for the member directory. It mirrors the page's
  /// primary tabs, branch tabs, role/status tabs, search field and compact
  /// member rows instead of showing unrelated generic cards.
  static Widget membersDirectory() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(0, 12, 0, 120),
        children: [
          _tabStripSkeleton(count: 2, width: 92),
          const SizedBox(height: 8),
          _tabStripSkeleton(count: 3, width: 68),
          const SizedBox(height: 10),
          _tabStripSkeleton(count: 4, width: 72),
          const SizedBox(height: 12),
          Container(
            height: 44,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 16),
          ...List.generate(
            7,
            (_) => Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
              child: SizedBox(
                height: 62,
                child: Row(
                  children: const [
                    CircleAvatar(radius: 22, backgroundColor: Colors.white),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                              width: 145,
                              height: 13,
                              child: ColoredBox(color: Colors.white)),
                          SizedBox(height: 7),
                          SizedBox(
                              width: 205,
                              height: 10,
                              child: ColoredBox(color: Colors.white)),
                        ],
                      ),
                    ),
                    SizedBox(width: 8),
                    SizedBox(
                        width: 45,
                        height: 19,
                        child: ColoredBox(color: Colors.white)),
                    SizedBox(width: 8),
                    SizedBox(
                        width: 16,
                        height: 16,
                        child: ColoredBox(color: Colors.white)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _tabStripSkeleton({required int count, required double width}) {
    return SizedBox(
      height: 44,
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
            count,
            (index) => Padding(
              padding: EdgeInsets.only(right: index == count - 1 ? 0 : 12),
              child: SizedBox(
                width: width,
                height: 18,
                child: const ColoredBox(color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Widget profile() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Row(
            children: [
              Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8))),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(width: 150, height: 20, color: Colors.white),
                  const SizedBox(height: 4),
                  Container(width: 100, height: 12, color: Colors.white),
                ],
              )
            ],
          ),
          const SizedBox(height: 32),
          Center(
            child: Container(
                width: 88,
                height: 88,
                decoration: const BoxDecoration(
                    color: Colors.white, shape: BoxShape.circle)),
          ),
          const SizedBox(height: 48),
          Container(width: 100, height: 16, color: Colors.white),
          const SizedBox(height: 10),
          Container(
              width: double.infinity,
              height: 50,
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10))),
          const SizedBox(height: 24),
          Container(width: 100, height: 16, color: Colors.white),
          const SizedBox(height: 10),
          Container(
              width: double.infinity,
              height: 50,
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10))),
        ],
      ),
    );
  }
}

class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: 6,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    height: 16,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 200,
                    height: 12,
                    color: Colors.white,
                  ),
                ],
              ),
            )
          ],
        );
      },
    );
  }
}
