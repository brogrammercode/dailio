import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';

class BranchPage extends StatelessWidget {
  const BranchPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Branch')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.people),
            title: const Text('Members'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.members),
          ),
          ListTile(
            leading: const Icon(Icons.assignment_ind),
            title: const Text('Join Requests'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.joinRequests),
          ),
          ListTile(
            leading: const Icon(Icons.manage_accounts),
            title: const Text('Roles & Permissions'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.loyalty),
            title: const Text('Plans & Pricing'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.schedule),
            title: const Text('Shifts'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.beach_access),
            title: const Text('Holidays & Leaves'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
        ],
      ),
    );
  }
}
