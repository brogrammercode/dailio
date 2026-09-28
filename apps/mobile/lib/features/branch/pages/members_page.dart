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
                  const SizedBox(height: 8),
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
                                      padding: const EdgeInsets.fromLTRB(
                                          0, 0, 0, 100),
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
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, -4))
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            context.push(AppRoutes.joinRequests);
                          },
                          icon: const Icon(Iconsax.task_square, size: 16),
                          label: const Text('Review Pending',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            context.push(AppRoutes.newAdmission);
                          },
                          icon: const Icon(Iconsax.user_add, size: 16),
                          label: const Text('+ Admission',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange.shade800,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
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
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8)),
            child: IconButton(
              icon: const Icon(Iconsax.arrow_left, size: 20),
              onPressed: () => context.pop(),
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              padding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Member Directory',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                SizedBox(height: 4),
                Text('Search, filter, and inspect members.',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8)),
            child: IconButton(
              icon: const Icon(Iconsax.document_download, size: 20),
              onPressed: () {},
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
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
      padding: const EdgeInsets.symmetric(vertical: 16),
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
            const SizedBox(height: 12),
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
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search member by name, ID, phone...',
                hintStyle: const TextStyle(fontSize: 14, color: Colors.grey),
                prefixIcon: const Icon(Iconsax.search_normal_1,
                    size: 18, color: Colors.grey),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade200)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade200)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        BorderSide(color: Colors.orange.shade400, width: 1.5)),
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
      borderRadius: BorderRadius.circular(20),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? Colors.black87 : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isActive ? Colors.black87 : Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
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
      borderRadius: BorderRadius.circular(20),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? Colors.orange.shade800 : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isActive ? Colors.orange.shade800 : Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
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
          const Icon(Iconsax.personalcard, size: 48, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('No members found',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
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
      padding: const EdgeInsets.only(bottom: 4),
      child: DailioCompactTile(
        avatar: Stack(
          children: [
            CircleAvatar(
              radius: 22,
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
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: CircleAvatar(
                  radius: 7,
                  backgroundColor: statusColor,
                  child: Icon(
                    member.status == 'ACTIVE'
                        ? Iconsax.tick_circle
                        : Iconsax.close_circle,
                    size: 10,
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
          AppRoutes.configureMember.replaceAll(':memberId', member.id),
        ),
      ),
    );
  }
}
