import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/widgets/dailio_simple_app_bar.dart';
import '../../context_selection/controllers/branch_repository.dart';
import '../widgets/meal_ui.dart';

class MealAttendanceQrPage extends StatefulWidget {
  final String token;
  final Map<String, dynamic> invite;

  const MealAttendanceQrPage({
    super.key,
    required this.token,
    required this.invite,
  });

  @override
  State<MealAttendanceQrPage> createState() => _MealAttendanceQrPageState();
}

class _MealAttendanceQrPageState extends State<MealAttendanceQrPage> {
  String? _selectedSlot;
  bool _busy = false;
  String? _message;
  bool _error = false;

  List<Map<String, dynamic>> get _slots =>
      ((widget.invite['meal_slots'] as List?) ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();

  Future<void> _mark() async {
    final slotId = _selectedSlot;
    if (slotId == null || _busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await context.read<BranchRepository>().serveMealFromInvite(
            widget.token,
            slotId,
            branchId: (widget.invite['branch'] as Map?)?['id']?.toString(),
            idempotencyKey:
                'mobile-meal-qr-${DateTime.now().toUtc().microsecondsSinceEpoch}',
          );
      if (mounted) {
        setState(() {
          _message = 'Meal attendance marked successfully.';
          _error = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _message = error.toString();
          _error = true;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final branch =
        (widget.invite['branch'] as Map?)?.cast<String, dynamic>() ?? {};
    return Scaffold(
      backgroundColor: MealUi.canvas,
      appBar: const DailioSimpleAppBar(),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16.r, 12.r, 16.r, 32.r),
        children: [
          Text('Meal attendance',
              style: TextStyle(fontSize: 20.r, fontWeight: FontWeight.w800)),
          SizedBox(height: 4.r),
          Text('${branch['name'] ?? 'Mess'} · Select what you are having',
              style: TextStyle(color: MealUi.muted, fontSize: 11.r)),
          SizedBox(height: 16.r),
          if (_message != null)
            Container(
              margin: EdgeInsets.only(bottom: 12.r),
              padding: EdgeInsets.all(12.r),
              decoration: BoxDecoration(
                color: (_error ? MealUi.negative : MealUi.positive)
                    .withValues(alpha: .08),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Text(_message!, style: TextStyle(fontSize: 11.r)),
            ),
          MealPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Today’s meal',
                    style:
                        TextStyle(fontSize: 14.r, fontWeight: FontWeight.w700)),
                SizedBox(height: 10.r),
                ..._slots.map((slot) {
                  final id = slot['id'].toString();
                  final selected = _selectedSlot == id;
                  return Padding(
                    padding: EdgeInsets.only(bottom: 8.r),
                    child: InkWell(
                      onTap: _busy
                          ? null
                          : () => setState(() => _selectedSlot = id),
                      borderRadius: BorderRadius.circular(10.r),
                      child: Container(
                        padding: EdgeInsets.all(11.r),
                        decoration: BoxDecoration(
                          color: selected
                              ? MealUi.positive.withValues(alpha: .08)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(10.r),
                          border: Border.all(
                              color:
                                  selected ? MealUi.positive : MealUi.border),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              selected ? Iconsax.tick_circle5 : Iconsax.cup,
                              size: 18.r,
                              color: selected ? MealUi.positive : MealUi.muted,
                            ),
                            SizedBox(width: 10.r),
                            Expanded(
                              child: Text('${slot['name']}',
                                  style: TextStyle(
                                      fontSize: 13.r,
                                      fontWeight: FontWeight.w600)),
                            ),
                            Text(
                              '${slot['starts_at_local']}–${slot['ends_at_local']}',
                              style: TextStyle(
                                  fontSize: 10.r, color: MealUi.muted),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
                if (_slots.isEmpty)
                  Text('No meal windows are configured today.',
                      style: TextStyle(color: MealUi.muted, fontSize: 12.r)),
                SizedBox(height: 8.r),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _selectedSlot == null || _busy ? null : _mark,
                    icon: _busy
                        ? SizedBox(
                            width: 16.r,
                            height: 16.r,
                            child: const CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : Icon(Iconsax.tick_circle, size: 17.r),
                    label: Text(_busy ? 'Marking…' : 'Mark meal attendance'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
