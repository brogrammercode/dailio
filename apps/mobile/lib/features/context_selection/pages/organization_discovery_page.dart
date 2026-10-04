import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/router/route_names.dart';
import '../../../core/widgets/dailio_onboarding_widgets.dart';
import '../../../core/widgets/dailio_overflow_menu.dart';
import '../../../core/widgets/dailio_simple_app_bar.dart';
import '../../../core/widgets/shimmer_loader.dart';
import '../controllers/branch_repository.dart';
import '../models/branch_discovery_model.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class OrganizationDiscoveryPage extends StatefulWidget {
  const OrganizationDiscoveryPage({super.key});

  @override
  State<OrganizationDiscoveryPage> createState() =>
      _OrganizationDiscoveryPageState();
}

class _OrganizationDiscoveryPageState extends State<OrganizationDiscoveryPage> {
  final _searchController = TextEditingController();
  late final BranchRepository _repository;
  List<BranchDiscoveryModel> _locations = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repository = context.read<BranchRepository>();
    _search();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results =
          await _repository.discoverBranches(query: _searchController.text);
      if (mounted) setState(() => _locations = results);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load organizations.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<BranchDiscoveryModel>>{};
    for (final location in _locations) {
      grouped.putIfAbsent(location.organizationId, () => []).add(location);
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: DailioSimpleAppBar(
        onBack: () => context.pop(),
        menuItems: const [
          DailioMenuItem(
              value: 'scan', icon: Iconsax.scan_barcode, label: 'Scan QR'),
        ],
        onMenuSelected: (_) => context.push(AppRoutes.qrScanner),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16.r, 14.r, 16.r, 10.r),
              child: TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _search(),
                decoration: dailioOnboardingInput(
                  'Search organizations or cities',
                  Iconsax.search_normal_1,
                  suffixIcon: IconButton(
                    onPressed: _search,
                    icon: Icon(Iconsax.arrow_right_1, size: 17.r),
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(16.r, 0, 16.r, 10.r),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Organizations near you',
                    style:
                        TextStyle(fontSize: 12.r, fontWeight: FontWeight.w800)),
              ),
            ),
            Expanded(
              child: _isLoading
                  ? ShimmerLoader.settingsList()
                  : _error != null
                      ? DailioOnboardingEmpty(
                          icon: Iconsax.cloud_cross,
                          title: 'Could not load organizations',
                          subtitle: _error!,
                          action: DailioOnboardingButton(
                            label: 'Try again',
                            icon: Iconsax.refresh,
                            onPressed: _search,
                          ),
                        )
                      : grouped.isEmpty
                          ? DailioOnboardingEmpty(
                              icon: Iconsax.search_status,
                              title: 'No organizations found',
                              subtitle:
                                  'Try another name or use a branch QR code.',
                              action: DailioOnboardingButton(
                                label: 'Scan QR',
                                icon: Iconsax.scan_barcode,
                                outlined: true,
                                onPressed: () =>
                                    context.push(AppRoutes.qrScanner),
                              ),
                            )
                          : _buildResults(grouped),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults(Map<String, List<BranchDiscoveryModel>> grouped) {
    final entries = grouped.entries.toList();
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(16.r, 0, 16.r, 32.r),
      itemCount: entries.length,
      separatorBuilder: (_, __) => Divider(height: 1.r, indent: 52.r),
      itemBuilder: (context, index) {
        final locations = entries[index].value;
        final organization = locations.first.organization;
        return DailioOnboardingInfoRow(
          icon: Iconsax.building_4,
          title: organization.name,
          subtitle:
              '${locations.length} branch${locations.length == 1 ? '' : 'es'} · Tap to view details',
          trailing:
              Icon(Iconsax.arrow_right_3, size: 17.r, color: Color(0xFF9A9A9A)),
          onTap: () => context.push(
              AppRoutes.orgDetail.replaceFirst(':orgId', entries[index].key),
              extra: locations),
        );
      },
    );
  }
}
