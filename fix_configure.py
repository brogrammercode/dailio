import re

with open('apps/mobile/lib/features/branch/pages/configure_member_page.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Add PayrollRepository import
content = content.replace("import '../controllers/shift_repository.dart';", "import '../controllers/shift_repository.dart';\nimport '../controllers/payroll_repository.dart';")

# Add _salaryStructures array
content = content.replace("List<Map<String, dynamic>> _shifts = [];", "List<Map<String, dynamic>> _shifts = [];\n  List<Map<String, dynamic>> _salaryStructures = [];")

# Add to Future.wait
content = content.replace("context.read<ShiftRepository>().listShifts(_orgId),", "context.read<ShiftRepository>().listShifts(_orgId),\n          context.read<PayrollRepository>().listSalaryStructures(_orgId),")

# Process futures results
content = content.replace("final shifts = (futures[4] as List).cast<Map<String, dynamic>>();", "final shifts = (futures[4] as List).cast<Map<String, dynamic>>();\n        final structures = (futures[5] as List).cast<Map<String, dynamic>>();")

# Set state variables
content = content.replace("_shifts = shifts;", "_shifts = shifts;\n        _salaryStructures = structures;")

# Update CircleAvatar in header
avatar_code_old = """CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.orange.shade100,
                      child: Text(_member!.name.substring(0, 1).toUpperCase(),
                          style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade800)),
                    ),"""
                    
avatar_code_new = """CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.orange.shade100,
                      backgroundImage: _member!.avatarUrl != null ? NetworkImage(_member!.avatarUrl!) : null,
                      child: _member!.avatarUrl == null ? Text(_member!.name.substring(0, 1).toUpperCase(),
                          style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade800)) : null,
                    ),"""
content = content.replace(avatar_code_old, avatar_code_new)

# Update dropdown for Payroll
dropdown_old = """items: const [DropdownMenuItem<String>(value: null, child: Text('No Salary Structure'))], // TODO: bind actual salary structures once backend supports it"""
dropdown_new = """items: [
                const DropdownMenuItem<String>(value: null, child: Text('No Salary Structure')),
                ..._salaryStructures.map((s) => DropdownMenuItem<String>(
                  value: s['id'],
                  child: Text(s['name']),
                )),
              ],"""
content = content.replace(dropdown_old, dropdown_new)

with open('apps/mobile/lib/features/branch/pages/configure_member_page.dart', 'w', encoding='utf-8') as f:
    f.write(content)
