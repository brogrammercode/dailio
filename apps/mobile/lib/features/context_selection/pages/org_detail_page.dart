import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/widgets/dailio_onboarding_widgets.dart';
import '../../../core/widgets/dailio_simple_app_bar.dart';
import '../controllers/branch_repository.dart';
import '../models/branch_discovery_model.dart';
import '../widgets/join_request_sheet.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class OrgDetailPage extends StatefulWidget {
  final List<BranchDiscoveryModel> locations;

  const OrgDetailPage({super.key, required this.locations});

  @override
  State<OrgDetailPage> createState() => _OrgDetailPageState();
}

class _OrgDetailPageState extends State<OrgDetailPage> {
  void _joinBranch(BranchDiscoveryModel location) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18.r)),
      ),
      builder: (_) => JoinRequestSheet(
        branch: location,
        onSubmit: (message, emergencyName, emergencyPhone, dob) async {
          await context
              .read<BranchRepository>()
              .joinBranch(location.id, message: message);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.locations.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: DailioSimpleAppBar(onBack: () => context.pop()),
        body: const DailioOnboardingEmpty(
          icon: Iconsax.building_4,
          title: 'No branches available',
          subtitle: 'This organization has no joinable branches right now.',
        ),
      );
    }

    final organization = widget.locations.first.organization;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: DailioSimpleAppBar(onBack: () => context.pop()),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(16.r, 16.r, 16.r, 32.r),
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 27.r,
                  backgroundColor: const Color(0xFFFFF1E6),
                  backgroundImage: organization.logoUrl == null
                      ? null
                      : NetworkImage(organization.logoUrl!),
                  child: organization.logoUrl == null
                      ? Icon(Iconsax.building_4,
                          color: Color(0xFFCC5A00), size: 24.r)
                      : null,
                ),
                SizedBox(width: 12.r),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(organization.name,
                          style: TextStyle(
                              fontSize: 18.r, fontWeight: FontWeight.w800)),
                      SizedBox(height: 3.r),
                      Text('Organization · Join a branch',
                          style: TextStyle(
                              fontSize: 12.r, color: Color(0xFF858585))),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 22.r),
            const DailioOnboardingSectionLabel('AVAILABLE BRANCHES'),
            ...widget.locations.asMap().entries.map((entry) {
              final location = entry.value;
              return Column(
                children: [
                  DailioOnboardingInfoRow(
                    icon: Iconsax.shop,
                    title: location.name,
                    subtitle: location.address ?? 'Address not available',
                    trailing: FilledButton(
                      onPressed: () => _joinBranch(location),
                      style: FilledButton.styleFrom(
                        minimumSize: Size(0, 34.r),
                        padding: EdgeInsets.symmetric(horizontal: 12.r),
                        backgroundColor: const Color(0xFFCC5A00),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.r)),
                      ),
                      child: Text('Join', style: TextStyle(fontSize: 12.r)),
                    ),
                  ),
                  if (entry.key != widget.locations.length - 1)
                    Divider(height: 1.r, indent: 52.r),
                ],
              );
            }),
            SizedBox(height: 22.r),
            Text(
              'Your request will remain pending until an authorized branch user approves it.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.r, color: Color(0xFF929292)),
            ),
          ],
        ),
      ),
    );
  }
}
