import 'package:flutter/material.dart';

class VariableSelector extends StatelessWidget {
  const VariableSelector({
    super.key,
    required this.selectedVariable,
    required this.onChanged,
    this.precipitation = false,
  });

  final selectedVariable;
  final onChanged;
  final precipitation;

  @override
  Widget build(BuildContext context) {
    final List<String> _variables =
        precipitation
            ? const ['RATE', 'PRECIPITATION', 'DBZH', 'VRADH', 'ZDR', 'KDP', 'PHIDP', 'RHOHV', 'WRADH', 'QUAL']
            : const ['RATE', 'DBZH', 'VRADH', 'ZDR', 'KDP', 'PHIDP', 'RHOHV', 'WRADH', 'QUAL'];

    return DropdownButtonFormField<String>(
      value: selectedVariable,
      items:
          _variables
              .map((v) => DropdownMenuItem(value: v, child: Text(v)))
              .toList(),
      onChanged: onChanged,
      decoration: const InputDecoration(
        labelText: 'Variable',
        border: OutlineInputBorder(),
      ),
    );
  }
}
