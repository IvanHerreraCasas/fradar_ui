import 'package:flutter/material.dart';

class VariableSelector extends StatelessWidget {
  const VariableSelector({
    super.key,
    required this.selectedVariable,
    required this.onChanged,
    this.precipitation = false,
  });

  final String selectedVariable;
  final ValueChanged<String?>? onChanged;
  final bool precipitation;

  @override
  Widget build(BuildContext context) {
    final List<String> variables =
        precipitation
            ? const ['RATE', 'PRECIPITATION', 'DBZH', 'VRADH', 'ZDR', 'KDP']
            : const ['RATE', 'DBZH', 'VRADH', 'ZDR', 'KDP'];

    return DropdownButtonFormField<String>(
      value: selectedVariable,
      items:
          variables
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
