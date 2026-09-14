const fs = require('fs');
let content = fs.readFileSync('apps/mobile/lib/features/branch/pages/configure_member_page.dart', 'utf-8');

content = content.replace(import '../controllers/shift_repository.dart';, import '../controllers/shift_repository.dart';\nimport '../controllers/payroll_repository.dart';);

content = content.replace(List<Map<String, dynamic>> _shifts = [];, List<Map<String, dynamic>> _shifts = [];\n  List<Map<String, dynamic>> _salaryStructures = [];);

content = content.replace(context.read<ShiftRepository>().listShifts(_orgId),, context.read<ShiftRepository>().listShifts(_orgId),\n          context.read<PayrollRepository>().listSalaryStructures(_orgId),);

content = content.replace(inal shifts = (futures[4] as List).cast<Map<String, dynamic>>();, inal shifts = (futures[4] as List).cast<Map<String, dynamic>>();\n        final structures = (futures[5] as List).cast<Map<String, dynamic>>(););

content = content.replace(_shifts = shifts;, _shifts = shifts;\n          _salaryStructures = structures;);

const avatarOld = CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.orange.shade100,
                      child: Text(_member!.name.substring(0, 1).toUpperCase(),
                          style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade800)),
                    ),;
const avatarNew = CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.orange.shade100,
                      backgroundImage: _member!.avatarUrl != null ? NetworkImage(_member!.avatarUrl!) : null,
                      child: _member!.avatarUrl == null ? Text(_member!.name.substring(0, 1).toUpperCase(),
                          style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade800)) : null,
                    ),;
content = content.replace(avatarOld, avatarNew);

const dropdownOld = items: const [DropdownMenuItem<String>(value: null, child: Text('No Salary Structure'))], // TODO: bind actual salary structures once backend supports it;
const dropdownNew = items: [
                const DropdownMenuItem<String>(value: null, child: Text('No Salary Structure')),
                ..._salaryStructures.map((s) => DropdownMenuItem<String>(
                  value: s['id'],
                  child: Text(s['name']),
                )),
              ],;
content = content.replace(dropdownOld, dropdownNew);

fs.writeFileSync('apps/mobile/lib/features/branch/pages/configure_member_page.dart', content, 'utf-8');
