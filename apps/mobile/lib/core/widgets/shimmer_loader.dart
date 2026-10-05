import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

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
        padding: EdgeInsets.only(top: 12.r, bottom: 96.r),
        itemCount: 6,
        separatorBuilder: (_, __) => SizedBox(height: 8.r),
        itemBuilder: (_, __) => Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.r),
          child: SizedBox(
            height: 68.r,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(radius: 24.r, backgroundColor: Colors.white),
                SizedBox(width: 12.r),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 150.r,
                        height: 14.r,
                        child: ColoredBox(color: Colors.white),
                      ),
                      SizedBox(height: 8.r),
                      SizedBox(
                        width: 210.r,
                        height: 11.r,
                        child: ColoredBox(color: Colors.white),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 12.r),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    SizedBox(
                      width: 54.r,
                      height: 11.r,
                      child: ColoredBox(color: Colors.white),
                    ),
                    SizedBox(height: 9.r),
                    SizedBox(
                      width: 18.r,
                      height: 4.r,
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
        padding: EdgeInsets.all(24.r),
        itemCount: 5,
        separatorBuilder: (_, __) => SizedBox(height: 24.r),
        itemBuilder: (_, __) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(width: 120.r, height: 16.r, color: Colors.white),
            SizedBox(height: 10.r),
            Container(
                width: double.infinity,
                height: 50.r,
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10.r))),
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
        padding: EdgeInsets.all(24.r),
        itemCount: 4,
        separatorBuilder: (_, __) => SizedBox(height: 16.r),
        itemBuilder: (_, __) => Container(
          width: double.infinity,
          height: 100.r,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12.r),
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
        padding: EdgeInsets.fromLTRB(16.r, 12.r, 16.r, 100.r),
        itemCount: count,
        separatorBuilder: (_, __) => SizedBox(height: 8.r),
        itemBuilder: (_, __) => Container(
          height: 68.r,
          padding: EdgeInsets.symmetric(horizontal: 12.r),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10.r),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 38.r,
                height: 38.r,
                child: ColoredBox(color: Colors.white),
              ),
              SizedBox(width: 12.r),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                        width: 150.r,
                        height: 13.r,
                        child: ColoredBox(color: Colors.white)),
                    SizedBox(height: 8.r),
                    SizedBox(
                        width: 210.r,
                        height: 10.r,
                        child: ColoredBox(color: Colors.white)),
                  ],
                ),
              ),
              SizedBox(width: 12.r),
              SizedBox(
                  width: 34.r,
                  height: 12.r,
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
        padding: EdgeInsets.fromLTRB(16.r, 16.r, 16.r, 100.r),
        children: [
          if (withAvatar) ...[
            Center(
              child: SizedBox(
                  width: 76.r,
                  height: 76.r,
                  child: ColoredBox(color: Colors.white)),
            ),
            SizedBox(height: 22.r),
          ],
          ...List.generate(
            5,
            (_) => Padding(
              padding: EdgeInsets.only(bottom: 16.r),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                      width: 120.r,
                      height: 11.r,
                      child: ColoredBox(color: Colors.white)),
                  SizedBox(height: 7.r),
                  SizedBox(
                    width: double.infinity,
                    height: 48.r,
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

  /// Geometry-matched loading state for the Meals workspace: page heading,
  /// secondary context line, local tab strip, and the compact form/row shapes
  /// used by Serve and Configure.
  static Widget meals() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16.r, 12.r, 16.r, 100.r),
        children: [
          SizedBox(width: 90.r, height: 18.r, child: const ColoredBox(color: Colors.white)),
          SizedBox(height: 6.r),
          SizedBox(width: 120.r, height: 11.r, child: const ColoredBox(color: Colors.white)),
          SizedBox(height: 14.r),
          Container(
            height: 44.r,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                SizedBox(width: 70.r, height: 14.r, child: const ColoredBox(color: Colors.white)),
                SizedBox(width: 22.r),
                SizedBox(width: 90.r, height: 14.r, child: const ColoredBox(color: Colors.white)),
              ],
            ),
          ),
          SizedBox(height: 18.r),
          SizedBox(width: 90.r, height: 14.r, child: const ColoredBox(color: Colors.white)),
          SizedBox(height: 8.r),
          Container(
            height: 54.r,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10.r),
            ),
          ),
          SizedBox(height: 12.r),
          Container(
            height: 54.r,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10.r),
            ),
          ),
          SizedBox(height: 18.r),
          Container(
            height: 108.r,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12.r),
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
        padding: EdgeInsets.fromLTRB(16.r, 4.r, 16.r, 120.r),
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: List.generate(
                    3,
                    (index) => Padding(
                      padding: EdgeInsets.only(right: index == 2 ? 0 : 12.r),
                      child: SizedBox(
                        width: 64.r,
                        height: 18.r,
                        child: ColoredBox(color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(
                  width: 24.r,
                  height: 24.r,
                  child: ColoredBox(color: Colors.white)),
            ],
          ),
          SizedBox(height: 20.r),
          SizedBox(
              width: 110.r,
              height: 16.r,
              child: ColoredBox(color: Colors.white)),
          SizedBox(height: 16.r),
          ...List.generate(
            5,
            (index) => Padding(
              padding: EdgeInsets.only(bottom: 14.r),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                      width: 92.r,
                      height: 11.r,
                      child: ColoredBox(color: Colors.white)),
                  SizedBox(height: 8.r),
                  SizedBox(
                    height: index == 4 ? 44.r : 48.r,
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
        padding: EdgeInsets.fromLTRB(16.r, 20.r, 16.r, 30.r),
        children: [
          SizedBox(
              width: 130.r,
              height: 22.r,
              child: ColoredBox(color: Colors.white)),
          SizedBox(height: 7.r),
          SizedBox(
              width: 250.r,
              height: 12.r,
              child: ColoredBox(color: Colors.white)),
          SizedBox(height: 20.r),
          ...List.generate(
            4,
            (_) => Padding(
              padding: EdgeInsets.only(bottom: 8.r),
              child: SizedBox(
                  height: 58.r, child: ColoredBox(color: Colors.white)),
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
        padding: EdgeInsets.fromLTRB(16.r, 16.r, 16.r, 32.r),
        children: [
          Row(
            children: [
              CircleAvatar(radius: 25.r, backgroundColor: Colors.white),
              SizedBox(width: 12.r),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                        width: 160.r,
                        height: 16.r,
                        child: ColoredBox(color: Colors.white)),
                    SizedBox(height: 7.r),
                    SizedBox(
                        width: 110.r,
                        height: 11.r,
                        child: ColoredBox(color: Colors.white)),
                  ],
                ),
              ),
              SizedBox(
                  width: 64.r,
                  height: 22.r,
                  child: ColoredBox(color: Colors.white)),
            ],
          ),
          SizedBox(height: 26.r),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SizedBox(
                  width: 120.r,
                  height: 30.r,
                  child: ColoredBox(color: Colors.white)),
              SizedBox(
                  width: 90.r,
                  height: 24.r,
                  child: ColoredBox(color: Colors.white)),
            ],
          ),
          SizedBox(height: 22.r),
          ...List.generate(
            4,
            (_) => Padding(
              padding: EdgeInsets.only(bottom: 14.r),
              child: SizedBox(
                  height: 92.r, child: ColoredBox(color: Colors.white)),
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
        padding: EdgeInsets.fromLTRB(16.r, 20.r, 16.r, 32.r),
        children: [
          Center(
              child: SizedBox(
                  width: 140.r,
                  height: 28.r,
                  child: ColoredBox(color: Colors.white))),
          SizedBox(height: 8.r),
          Center(
              child: SizedBox(
                  width: 170.r,
                  height: 12.r,
                  child: ColoredBox(color: Colors.white))),
          SizedBox(height: 28.r),
          Center(
              child: SizedBox(
                  width: 220.r,
                  height: 220.r,
                  child: DecoratedBox(
                      decoration: BoxDecoration(
                          color: Colors.white, shape: BoxShape.circle)))),
          SizedBox(height: 28.r),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(
              3,
              (_) => SizedBox(
                  width: 70.r,
                  height: 42.r,
                  child: ColoredBox(color: Colors.white)),
            ),
          ),
          SizedBox(height: 24.r),
          SizedBox(height: 150.r, child: ColoredBox(color: Colors.white)),
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
        padding: EdgeInsets.fromLTRB(16.r, 12.r, 16.r, 100.r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: 44.r, child: ColoredBox(color: Colors.white)),
            SizedBox(height: 10.r),
            SizedBox(height: 42.r, child: ColoredBox(color: Colors.white)),
            SizedBox(height: 14.r),
            ...List.generate(
              6,
              (_) => Padding(
                padding: EdgeInsets.only(bottom: 8.r),
                child: SizedBox(
                    height: 68.r, child: ColoredBox(color: Colors.white)),
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
        padding: EdgeInsets.fromLTRB(0, 12.r, 0, 120.r),
        children: [
          _tabStripSkeleton(count: 3, width: 62.r),
          SizedBox(height: 10.r),
          _tabStripSkeleton(count: 3, width: 72.r),
          SizedBox(height: 14.r),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.r),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  height: 54.r,
                  padding: EdgeInsets.symmetric(horizontal: 12.r),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                          width: 32.r,
                          height: 32.r,
                          child: ColoredBox(color: Colors.white)),
                      SizedBox(width: 12.r),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                                width: 130.r,
                                height: 13.r,
                                child: ColoredBox(color: Colors.white)),
                            SizedBox(height: 7.r),
                            SizedBox(
                                width: 190.r,
                                height: 10.r,
                                child: ColoredBox(color: Colors.white)),
                          ],
                        ),
                      ),
                      SizedBox(
                          width: 62.r,
                          height: 22.r,
                          child: ColoredBox(color: Colors.white)),
                    ],
                  ),
                ),
                SizedBox(height: 14.r),
                ...List.generate(
                  3,
                  (_) => Padding(
                    padding: EdgeInsets.only(bottom: 14.r),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            SizedBox(
                                width: 30.r,
                                height: 30.r,
                                child: ColoredBox(color: Colors.white)),
                            SizedBox(width: 10.r),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                      width: 150.r,
                                      height: 13.r,
                                      child: ColoredBox(color: Colors.white)),
                                  SizedBox(height: 6.r),
                                  SizedBox(
                                      width: 220.r,
                                      height: 10.r,
                                      child: ColoredBox(color: Colors.white)),
                                ],
                              ),
                            ),
                            SizedBox(
                                width: 54.r,
                                height: 20.r,
                                child: ColoredBox(color: Colors.white)),
                          ],
                        ),
                        SizedBox(height: 8.r),
                        ...List.generate(
                          3,
                          (_) => Padding(
                            padding: EdgeInsets.only(bottom: 8.r),
                            child: SizedBox(
                                height: 38.r,
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
        padding: EdgeInsets.fromLTRB(0, 12.r, 0, 120.r),
        children: [
          _tabStripSkeleton(count: 2, width: 92.r),
          SizedBox(height: 8.r),
          _tabStripSkeleton(count: 3, width: 68.r),
          SizedBox(height: 10.r),
          _tabStripSkeleton(count: 4, width: 72.r),
          SizedBox(height: 12.r),
          Container(
            height: 44.r,
            margin: EdgeInsets.symmetric(horizontal: 16.r),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10.r),
            ),
          ),
          SizedBox(height: 16.r),
          ...List.generate(
            7,
            (_) => Padding(
              padding: EdgeInsets.fromLTRB(16.r, 0, 8.r, 8.r),
              child: SizedBox(
                height: 62.r,
                child: Row(
                  children: [
                    CircleAvatar(radius: 22.r, backgroundColor: Colors.white),
                    SizedBox(width: 10.r),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                              width: 145.r,
                              height: 13.r,
                              child: ColoredBox(color: Colors.white)),
                          SizedBox(height: 7.r),
                          SizedBox(
                              width: 205.r,
                              height: 10.r,
                              child: ColoredBox(color: Colors.white)),
                        ],
                      ),
                    ),
                    SizedBox(width: 8.r),
                    SizedBox(
                        width: 45.r,
                        height: 19.r,
                        child: ColoredBox(color: Colors.white)),
                    SizedBox(width: 8.r),
                    SizedBox(
                        width: 16.r,
                        height: 16.r,
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
      height: 44.r,
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
            count,
            (index) => Padding(
              padding: EdgeInsets.only(right: index == count - 1 ? 0 : 12.r),
              child: SizedBox(
                width: width,
                height: 18.r,
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
        padding: EdgeInsets.all(24.r),
        children: [
          Row(
            children: [
              Container(
                  width: 40.r,
                  height: 40.r,
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8.r))),
              SizedBox(width: 12.r),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(width: 150.r, height: 20.r, color: Colors.white),
                  SizedBox(height: 4.r),
                  Container(width: 100.r, height: 12.r, color: Colors.white),
                ],
              )
            ],
          ),
          SizedBox(height: 32.r),
          Center(
            child: Container(
                width: 88.r,
                height: 88.r,
                decoration: const BoxDecoration(
                    color: Colors.white, shape: BoxShape.circle)),
          ),
          SizedBox(height: 48.r),
          Container(width: 100.r, height: 16.r, color: Colors.white),
          SizedBox(height: 10.r),
          Container(
              width: double.infinity,
              height: 50.r,
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10.r))),
          SizedBox(height: 24.r),
          Container(width: 100.r, height: 16.r, color: Colors.white),
          SizedBox(height: 10.r),
          Container(
              width: double.infinity,
              height: 50.r,
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10.r))),
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
      padding: EdgeInsets.all(16.r),
      itemCount: 6,
      separatorBuilder: (context, index) => SizedBox(height: 16.r),
      itemBuilder: (context, index) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48.r,
              height: 48.r,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
            SizedBox(width: 16.r),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    height: 16.r,
                    color: Colors.white,
                  ),
                  SizedBox(height: 8.r),
                  Container(
                    width: 200.r,
                    height: 12.r,
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
