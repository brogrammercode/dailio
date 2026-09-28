import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '../theme/app_colors.dart';

/// Compact, consistent picker field used by forms across Dailio.
///
/// It keeps the field appearance familiar, but replaces Flutter's large
/// platform dropdown popup with a small bottom-sheet option list that is
/// easier to scan and consistent on every screen.
class DailioPickerField<T> extends StatelessWidget {
  final T? initialValue;
  final List<DropdownMenuItem<T>> items;
  final InputDecoration decoration;
  final ValueChanged<T?>? onChanged;
  final FormFieldValidator<T>? validator;
  final bool enabled;

  const DailioPickerField({
    super.key,
    required this.initialValue,
    required this.items,
    required this.decoration,
    this.onChanged,
    this.validator,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return FormField<T>(
      initialValue: initialValue,
      enabled: enabled,
      validator: validator,
      builder: (state) {
        final selected = _itemFor(state.value);
        final fieldDecoration = decoration.copyWith(
          errorText: state.errorText,
          suffixIcon: Icon(
            Iconsax.arrow_down_1,
            size: 18,
            color: enabled ? AppColors.brandDark : const Color(0xFFB5B5B5),
          ),
        );
        return Semantics(
          button: true,
          enabled: enabled,
          label: decoration.labelText ?? decoration.hintText,
          child: InkWell(
            onTap: enabled ? () => _open(context, state) : null,
            borderRadius: BorderRadius.circular(10),
            child: InputDecorator(
              decoration: fieldDecoration,
              isEmpty: selected == null,
              child: selected?.child ??
                  Text(
                    decoration.hintText ?? 'Select an option',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF8A8A8A),
                    ),
                  ),
            ),
          ),
        );
      },
    );
  }

  DropdownMenuItem<T>? _itemFor(T? value) {
    for (final item in items) {
      if (item.value == value) return item;
    }
    return null;
  }

  Future<void> _open(BuildContext context, FormFieldState<T> state) async {
    final result = await showModalBottomSheet<_DailioPickerSelection<T>>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxHeight: 460),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) => _DailioPickerSheet<T>(
        title:
            decoration.labelText ?? decoration.hintText ?? 'Select an option',
        selectedValue: state.value,
        items: items,
      ),
    );
    if (result == null || !context.mounted) return;
    state.didChange(result.value);
    onChanged?.call(result.value);
  }
}

class _DailioPickerSheet<T> extends StatelessWidget {
  final String title;
  final T? selectedValue;
  final List<DropdownMenuItem<T>> items;

  const _DailioPickerSheet({
    required this.title,
    required this.selectedValue,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 34,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD6D6D6),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.brandDark,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: items.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, color: Color(0xFFF0F0F0)),
                itemBuilder: (context, index) {
                  final item = items[index];
                  final active = item.value == selectedValue;
                  return InkWell(
                    onTap: item.enabled
                        ? () => Navigator.pop(
                            context, _DailioPickerSelection<T>(item.value))
                        : null,
                    borderRadius: BorderRadius.circular(9),
                    child: SizedBox(
                      height: 48,
                      child: Row(
                        children: [
                          Expanded(child: item.child),
                          if (active)
                            const Icon(
                              Iconsax.tick_circle5,
                              size: 19,
                              color: AppColors.brandAccent,
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DailioPickerSelection<T> {
  final T? value;

  const _DailioPickerSelection(this.value);
}
