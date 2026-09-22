import 'package:flutter/material.dart';

import '../../app/whynot_theme.dart';
import '../domain/city.dart';

/// Lets users type a city name, then choose a canonical Firestore city.
class CitySelector extends StatelessWidget {
  const CitySelector({
    required this.cities,
    required this.controller,
    required this.selectedId,
    required this.onSelected,
    super.key,
  });

  final List<City> cities;
  final TextEditingController controller;
  final String? selectedId;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return DropdownMenu<String>(
          width: constraints.maxWidth,
          controller: controller,
          initialSelection: selectedId,
          enableFilter: true,
          filterCallback: (entries, filter) {
            final search = _normalize(filter);
            return entries
                .where((entry) => _normalize(entry.label).contains(search))
                .toList();
          },
          requestFocusOnTap: true,
          menuHeight: 240,
          hintText: 'Type to search',
          onSelected: onSelected,
          textStyle: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            fontWeight: FontWeight.w300,
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: WhyNotColors.field,
            contentPadding: const EdgeInsets.symmetric(horizontal: 13),
            enabledBorder: fieldBorder(),
            focusedBorder: fieldBorder(color: WhyNotColors.muted),
          ),
          dropdownMenuEntries: [
            for (final city in cities)
              DropdownMenuEntry(value: city.id, label: city.name),
          ],
        );
      },
    );
  }

  String _normalize(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ü', 'u')
      .replaceAll('ñ', 'n');
}
