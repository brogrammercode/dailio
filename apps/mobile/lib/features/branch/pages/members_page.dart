import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax/iconsax.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/storage/preferences_storage.dart';
import '../../../core/widgets/shimmer_loader.dart';
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

  @override
  void initState() {
    super.initState();
    _repo = context.read<MembersRepository>();
    _orgRepo = context.read<OrganizationRepository>();
    _branchId = context.read<PreferencesStorage>().activeBranchId!;
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
      final roleMaps = await _orgRepo.getRoles(_orgId);
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
      final data = await _repo.listMembers(
        _branchId,
        search: _currentSearch,
        status: _currentStatus,
        roleId: _currentRoleId,
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
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(context),
                _buildTabs(context),
                _buildSearchAndFilters(),
                Expanded(
                  child: _isLoading
                      ? ShimmerLoader.list()
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
                                        24, 0, 24, 100),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Iconsax.personalcard,
                      size: 16, color: Colors.orange),
                  const SizedBox(width: 8),
                  const Text('Directory',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12)),
                    child: Text(_meta['total']?.toString() ?? '-',
                        style: const TextStyle(
                            fontSize: 10, fontWeight: FontWeight.bold)),
                  )
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              onTap: () => context.push(AppRoutes.joinRequests),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Iconsax.user_add, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    const Text('Join Requests',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
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
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade200)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade200)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Role Filters
          if (_roles.isNotEmpty) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  _buildRoleChip('All Roles', null),
                  ..._roles.map((r) => _buildRoleChip(r.name, r.id)),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          // Status Filters
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                _buildFilterChip('All Status', null),
                _buildFilterChip('Active', 'ACTIVE'),
                _buildFilterChip('Suspended', 'SUSPENDED'),
                _buildFilterChip('Inactive', 'INACTIVE'),
              ],
            ),
          ),
        ],
      ),
    );
  }

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
    final bool isWarning = member.status != 'ACTIVE';
    final Color statusColor = member.status == 'ACTIVE'
        ? Colors.green
        : (member.status == 'SUSPENDED' ? Colors.red : Colors.grey);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isWarning ? Colors.red.shade200 : Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: Colors.orange.shade100,
                    child: Text(member.name.substring(0, 1).toUpperCase(),
                        style: TextStyle(
                            color: Colors.orange.shade800,
                            fontWeight: FontWeight.bold,
                            fontSize: 18)),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                          color: Colors.white, shape: BoxShape.circle),
                      child: CircleAvatar(
                          radius: 8,
                          backgroundColor: statusColor,
                          child: const Icon(Icons.bolt,
                              size: 10, color: Colors.white)),
                    ),
                  )
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(member.name,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text(member.email ?? member.phone ?? 'No contact info',
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey),
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (member.role != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(4)),
                            child: Text(member.role!.name.toUpperCase(),
                                style: TextStyle(
                                    fontSize: 9,
                                    color: Colors.orange.shade800,
                                    fontWeight: FontWeight.bold)),
                          ),
                        if (member.joinedAt != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(4)),
                            child: Text(
                                'Joined ${member.joinedAt!.split('T')[0]}',
                                style: const TextStyle(
                                    fontSize: 9,
                                    color: Colors.grey,
                                    fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () {
                  context.push(AppRoutes.configureMember
                      .replaceAll(':memberId', member.id));
                },
                icon: const Icon(Iconsax.setting_4, size: 14),
                label: const Text('Configure',
                    style: TextStyle(fontSize: 11, color: Colors.black)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  minimumSize: const Size(0, 32),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              )
            ],
          ),
          const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1)),
          Row(
            children: [
              Text('ID:',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
              const SizedBox(width: 4),
              Text(
                  member.membershipNumber.isNotEmpty
                      ? member.membershipNumber
                      : member.id.substring(0, 8),
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold)),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                    color: isWarning
                        ? Colors.red.shade50
                        : statusColor.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: isWarning
                        ? Border.all(color: Colors.red.shade100)
                        : null),
                child: Row(
                  children: [
                    CircleAvatar(radius: 3, backgroundColor: statusColor),
                    const SizedBox(width: 4),
                    Text(member.status,
                        style: TextStyle(
                            fontSize: 10,
                            color: statusColor,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              )
            ],
          )
        ],
      ),
    );
  }
}
