import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax/iconsax.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/storage/preferences_storage.dart';
import '../../../core/widgets/shimmer_loader.dart';
import '../../../core/widgets/branch_filter_tabs.dart';
import '../../../core/widgets/dailio_compact_tile.dart';
import '../../../core/widgets/dailio_member_profile_sheet.dart';
import '../../../core/widgets/dailio_overflow_menu.dart';
import '../../../core/widgets/dailio_simple_app_bar.dart';
import '../../../core/widgets/dailio_tab_strip.dart';
import '../../organization/controllers/organization_repository.dart';
import '../../organization/models/role_model.dart';
import '../controllers/members_repository.dart';
import '../models/member_model.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class MembersPage extends StatefulWidget {
  const MembersPage({super.key});

  @override
  State<MembersPage> createState() => _MembersPageState();
}

class _MembersPageState extends State<MembersPage> {
  bool _isLoading = true;
  String? _errorMessage;
  List<MemberModel> _members = [];
  List<RoleModel> _roles = [];
  Map<String, dynamic> _meta = {};

  late final MembersRepository _repo;
  late final OrganizationRepository _orgRepo;
  late final String _branchId;
  late final String _orgId;

  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  String _currentSearch = '';
  String? _currentStatus; // null for all
  String? _currentRoleId; // null for all
  String? _selectedFilterBranchId;

  @override
  void initState() {
    super.initState();
    _repo = context.read<MembersRepository>();
    _orgRepo = context.read<OrganizationRepository>();
    _branchId = context.read<PreferencesStorage>().activeBranchId!;
    _selectedFilterBranchId = _branchId;
    _orgId = context.read<PreferencesStorage>().activeOrganizationId!;

    _loadInitialData();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      final roleMaps = await _orgRepo.getRoles(
        _orgId,
        onFresh: (freshRoles) {
          if (!mounted) return;
          setState(() {
            _roles = freshRoles.map((e) => RoleModel.fromJson(e)).toList();
          });
        },
      );
      final roles = roleMaps.map((e) => RoleModel.fromJson(e)).toList();
      if (mounted) {
        setState(() {
          _roles = roles;
        });
      }
    } catch (e) {
      debugPrint("Failed to load roles: $e");
    }
    _loadMembers();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (_currentSearch != _searchController.text) {
        setState(() {
          _currentSearch = _searchController.text;
        });
        _loadMembers();
      }
    });
  }

  Future<void> _loadMembers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final data = await _repo.listOrganizationMembers(
        _orgId,
        branchId: _selectedFilterBranchId,
        search: _currentSearch,
        status: _currentStatus,
        roleId: _currentRoleId,
        onFresh: (freshData) {
          if (!mounted) return;
          final freshList = ((freshData['data'] ?? []) as List)
              .map((e) => MemberModel.fromJson(e))
              .toList();
          setState(() {
            _members = freshList;
            _meta = freshData;
          });
        },
      );
      final list = ((data['data'] ?? []) as List)
          .map((e) => MemberModel.fromJson(e))
          .toList();
      setState(() {
        _members = list;
        _meta = data;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _setFilter(String? status) {
    setState(() {
      _currentStatus = status;
    });
    _loadMembers();
  }

  void _setRoleFilter(String? roleId) {
    setState(() {
      _currentRoleId = roleId;
    });
    _loadMembers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: DailioSimpleAppBar(
        onBack: () => context.pop(),
        menuItems: const [
          DailioMenuItem(
            value: 'refresh',
            icon: Iconsax.refresh,
            label: 'Refresh members',
          ),
        ],
        onMenuSelected: (_) => _loadMembers(),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            if (_isLoading)
              ShimmerLoader.membersDirectory()
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildTabs(context),
                  SizedBox(height: 8.r),
                  BranchFilterTabs(
                      contentPadding: EdgeInsets.zero,
                      centered: true,
                      selectedBranchId: _selectedFilterBranchId,
                      onChanged: (val) {
                        setState(() {
                          _selectedFilterBranchId = val;
                        });
                        _loadMembers();
                      }),
                  _buildSearchAndFilters(),
                  Expanded(
                    child: _isLoading
                        ? ShimmerLoader.membersDirectory()
                        : _errorMessage != null
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text('Error: $_errorMessage'),
                                    TextButton(
                                        onPressed: _loadMembers,
                                        child: const Text('Retry'))
                                  ],
                                ),
                              )
                            : _members.isEmpty
                                ? _buildEmptyState()
                                : RefreshIndicator(
                                    onRefresh: _loadMembers,
                                    child: ListView.builder(
                                      padding:
                                          EdgeInsets.fromLTRB(0, 0, 0, 100.r),
                                      itemCount: _members.length,
                                      itemBuilder: (context, index) {
                                        return _buildMemberCard(
                                            context, _members[index]);
                                      },
                                    ),
                                  ),
                  ),
                ],
              ),

            // Bottom Bar
            if (!_isLoading)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.fromLTRB(24.r, 16.r, 24.r, 32.r),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10.r,
                          offset: Offset(0, (-4).r))
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            context.push(AppRoutes.joinRequests);
                          },
                          icon: Icon(Iconsax.task_square, size: 16.r),
                          label: const Text('Review Pending',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 16.r),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.r)),
                          ),
                        ),
                      ),
                      SizedBox(width: 12.r),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            context.push(AppRoutes.newAdmission);
                          },
                          icon: Icon(Iconsax.user_add, size: 16.r),
                          label: const Text('+ Admission',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange.shade800,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 16.r),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.r)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
          ],
        ),
      ),
    );
  }

  // Kept for the legacy layout contract; the page now uses the shared bar.
  // ignore: unused_element
  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24.r, 16.r, 24.r, 16.r),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8.r)),
            child: IconButton(
              icon: Icon(Iconsax.arrow_left, size: 20.r),
              onPressed: () => context.pop(),
              constraints: BoxConstraints(minWidth: 40.r, minHeight: 40.r),
              padding: EdgeInsets.zero,
            ),
          ),
          SizedBox(width: 12.r),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Member Directory',
                    style:
                        TextStyle(fontSize: 20.r, fontWeight: FontWeight.bold)),
                SizedBox(height: 4.r),
                Text('Search, filter, and inspect members.',
                    style: TextStyle(fontSize: 12.r, color: Colors.grey)),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8.r)),
            child: IconButton(
              icon: Icon(Iconsax.document_download, size: 20.r),
              onPressed: () {},
              constraints: BoxConstraints(minWidth: 40.r, minHeight: 40.r),
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs(BuildContext context) {
    return DailioTabStrip<String>(
      tabs: [
        DailioTabItem(
          value: 'directory',
          label:
              'Directory ${_meta['total'] == null ? '' : '(${_meta['total']})'}',
        ),
        const DailioTabItem(value: 'requests', label: 'Join Requests'),
      ],
      selected: 'directory',
      centered: true,
      onChanged: (value) {
        if (value == 'requests') context.push(AppRoutes.joinRequests);
      },
    );
  }

  Widget _buildSearchAndFilters() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 16.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Role Filters
          if (_roles.isNotEmpty) ...[
            DailioTabStrip<String?>(
              tabs: [
                const DailioTabItem(value: null, label: 'All Roles'),
                ..._roles.map((role) => DailioTabItem<String?>(
                      value: role.id,
                      label: role.name,
                    )),
              ],
              selected: _currentRoleId,
              centered: true,
              onChanged: _setRoleFilter,
            ),
            SizedBox(height: 12.r),
          ],
          // Status Filters
          DailioTabStrip<String?>(
            tabs: const [
              DailioTabItem(value: null, label: 'All Status'),
              DailioTabItem(value: 'ACTIVE', label: 'Active'),
              DailioTabItem(value: 'SUSPENDED', label: 'Suspended'),
              DailioTabItem(value: 'INACTIVE', label: 'Inactive'),
            ],
            selected: _currentStatus,
            centered: true,
            onChanged: _setFilter,
          ),
          SizedBox(height: 14.r),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.r),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search member by name, ID, phone...',
                hintStyle: TextStyle(fontSize: 14.r, color: Colors.grey),
                prefixIcon: Icon(Iconsax.search_normal_1,
                    size: 18.r, color: Colors.grey),
                filled: true,
                fillColor: Colors.white,
                contentPadding: EdgeInsets.symmetric(vertical: 12.r),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.r),
                    borderSide: BorderSide(color: Colors.grey.shade200)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.r),
                    borderSide: BorderSide(color: Colors.grey.shade200)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.r),
                    borderSide: BorderSide(
                        color: Colors.orange.shade400, width: 1.5.r)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Legacy chip builders retained for compatibility with older saved layouts.
  // ignore: unused_element
  Widget _buildRoleChip(String label, String? roleId) {
    final isActive = _currentRoleId == roleId;
    return InkWell(
      onTap: () => _setRoleFilter(roleId),
      borderRadius: BorderRadius.circular(20.r),
      child: Container(
        margin: EdgeInsets.only(right: 8.r),
        padding: EdgeInsets.symmetric(horizontal: 14.r, vertical: 6.r),
        decoration: BoxDecoration(
          color: isActive ? Colors.black87 : Colors.white,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
              color: isActive ? Colors.black87 : Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.r,
            color: isActive ? Colors.white : Colors.grey.shade700,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildFilterChip(String label, String? status) {
    final isActive = _currentStatus == status;
    return InkWell(
      onTap: () => _setFilter(status),
      borderRadius: BorderRadius.circular(20.r),
      child: Container(
        margin: EdgeInsets.only(right: 8.r),
        padding: EdgeInsets.symmetric(horizontal: 14.r, vertical: 6.r),
        decoration: BoxDecoration(
          color: isActive ? Colors.orange.shade800 : Colors.white,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
              color: isActive ? Colors.orange.shade800 : Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.r,
            color: isActive ? Colors.white : Colors.grey.shade700,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Iconsax.personalcard, size: 48.r, color: Colors.grey),
          SizedBox(height: 16.r),
          Text('No members found',
              style: TextStyle(fontSize: 18.r, fontWeight: FontWeight.bold)),
          SizedBox(height: 8.r),
          const Text('Try adjusting your search or filters.',
              style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildMemberCard(BuildContext context, MemberModel member) {
    final Color statusColor = member.status == 'ACTIVE'
        ? Colors.green
        : (member.status == 'SUSPENDED' ? Colors.red : Colors.grey);
    final subtitle = [
      member.email ?? member.phone ?? 'No contact info',
      if (member.joinedAt != null) 'Joined ${member.joinedAt!.split('T')[0]}',
    ].join(' · ');

    return Padding(
      padding: EdgeInsets.only(bottom: 4.r),
      child: DailioCompactTile(
        avatar: Stack(
          children: [
            CircleAvatar(
              radius: 22.r,
              backgroundColor: Colors.orange.shade100,
              backgroundImage: member.avatarUrl != null
                  ? NetworkImage(member.avatarUrl!)
                  : null,
              child: member.avatarUrl == null
                  ? Text(
                      member.name.isEmpty
                          ? '?'
                          : member.name.substring(0, 1).toUpperCase(),
                      style: TextStyle(
                        color: Colors.orange.shade800,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.all(2.r),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: CircleAvatar(
                  radius: 7.r,
                  backgroundColor: statusColor,
                  child: Icon(
                    member.status == 'ACTIVE'
                        ? Iconsax.tick_circle
                        : Iconsax.close_circle,
                    size: 10.r,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
        onAvatarTap: () => showDailioMemberProfileSheet(
          context,
          DailioMemberPreview(
            memberId: member.id,
            name: member.name,
            role: member.role?.name ?? 'Member',
            status: member.status,
            avatarUrl: member.avatarUrl,
            phone: member.phone,
            email: member.email,
            membershipNumber: member.membershipNumber,
            subscriptionLabel: member.activeSubscription?.planName,
          ),
        ),
        title: member.name,
        titleBadge: member.role?.name ?? 'Member',
        statusBadge: member.status,
        statusBadgeColor: statusColor,
        subtitle: subtitle,
        trailing: member.membershipNumber.isNotEmpty
            ? member.membershipNumber
            : member.id.length > 8
                ? member.id.substring(0, 8)
                : member.id,
        menuItems: const [
          DailioMenuItem(
            value: 'configure',
            icon: Iconsax.setting_4,
            label: 'Configure member',
          ),
        ],
        onMenuSelected: (value) {
          if (value == 'configure') {
            context.push(
              AppRoutes.configureMember.replaceAll(':memberId', member.id),
            );
          }
        },
        onTap: () => context.push(
          AppRoutes.memberDetail.replaceAll(':memberId', member.id),
        ),
      ),
    );
  }
}
