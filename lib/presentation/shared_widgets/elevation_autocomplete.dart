import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Required for FilteringTextInputFormatter

// Define a callback type for when an elevation is selected or submitted
typedef ElevationChangedCallback = void Function(double value);

class ElevationAutocomplete extends StatelessWidget {
  final double? initialValue; // Make initialValue nullable
  final bool enabled;
  final ElevationChangedCallback onSelected;
  final String labelText;
  final String hintText;
  // Optional: Add a validator function if needed
  // final String? Function(String?)? validator;

  const ElevationAutocomplete({
    super.key,
    required this.onSelected,
    this.initialValue = 2.5,
    this.enabled = true,
    this.labelText = 'Elevation (°)',
    this.hintText = 'e.g., 2.5',
    // this.validator,
  });


  // Add validation logic for elevation input
  String? _validateElevationInput(String? value) {
    if (value == null || value.isEmpty) {
      return 'Elevation cannot be empty';
    }
    final double? parsedValue = double.tryParse(value);
    if (parsedValue == null) {
      return 'Invalid number format';
    }
    if (parsedValue < 0 || parsedValue > 90) {
      // Example range validation
      return 'Elevation must be between 0 and 90';
    }
    // Optional: Check if value exists in _elevations list if strict selection is needed
    // if (!_elevations.contains(parsedValue)) {
    //    return 'Select a value from the list';
    // }
    return null; // Input is valid
  }

  // --- Helper to format double options ---
  String _formatDouble(double value) {
    return value.toStringAsFixed(1);
  }

  final List<double> _elevations = const [
    2.5,
    3.5,
    4.5,
    5.5,
    7.5,
    10.0,
    12.5,
    15.0,
  ];

  @override
  Widget build(BuildContext context) {
    // Use initialValue if provided, otherwise empty string
    final initialText =
        initialValue != null ? _formatDouble(initialValue!) : '';

    return LayoutBuilder(
      builder: (context, constraints) {
        return Autocomplete<double>(
          // --- Initial Value ---
          initialValue: TextEditingValue(text: initialText),
        
          // --- Options Logic ---
          optionsBuilder: (TextEditingValue textEditingValue) {
            final String query = textEditingValue.text;
            if (query == '') {
              // Return all options formatted if field is empty or just cleared
              return _elevations;
            }
            // Filter options based on input text (comparing formatted strings)
            return _elevations.where((double option) {
              return _formatDouble(option).startsWith(query);
            });
          },
        
          // --- Display String ---
          // How the option is displayed in the suggestions list
          displayStringForOption: _formatDouble,
        
          // --- Field Appearance (Input Field) ---
          fieldViewBuilder: (
            BuildContext context,
            TextEditingController fieldController,
            FocusNode fieldFocusNode,
            VoidCallback onFieldSubmitted, // Called when Enter is pressed in the field
          ) {
            // Note: Autocomplete manages its own fieldController.
            // We react to changes via onSelected or onFieldSubmitted.
            return TextFormField(
              controller: fieldController,
              focusNode: fieldFocusNode,
              enabled: enabled,
              decoration: InputDecoration(
                labelText: labelText,
                border: const OutlineInputBorder(),
                hintText: hintText,
                // Use the internal validator or pass one in
                errorText: _validateElevationInput(fieldController.text),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                // Allow digits and a single decimal point
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
              ],
              onFieldSubmitted: (String value) {
                // This is called when the user presses Enter/Done on the keyboard
                onFieldSubmitted(); // Closes the options view if open
        
                // Attempt to parse the typed value and call onSelected if valid
                final double? parsedValue = double.tryParse(value);
                if (parsedValue != null && _validateElevationInput(value) == null) {
                  onSelected(parsedValue); // Notify parent with the valid typed value
                }
                // Optionally unfocus after submission
                // fieldFocusNode.unfocus(); // Or FocusScope.of(context).unfocus();
              },
              // Optional: Add onChanged if real-time validation feedback is needed
              // onChanged: (value) {
              //   // Might trigger rebuilds frequently if validation logic is complex
              // },
            );
          },
        
          // --- Suggestions List Appearance ---
          optionsViewBuilder: (
            BuildContext context,
            // This is the callback for when an *option* is tapped in the list
            AutocompleteOnSelected<double> onAutocompleteSelected,
            Iterable<double> currentOptions,
          ) {
            // Get max width constraints directly here if needed
            // final screenWidth = MediaQuery.of(context).size.width;
            // final textFieldWidth = // Can try getting RenderBox size if needed precisely
        
            return Align(
              alignment: Alignment.topLeft,
              // Use LayoutBuilder *here* if you need precise alignment with the TextField width
              child: Material(
               elevation: 4.0,
               child: ConstrainedBox(
                 constraints: BoxConstraints(
                   maxHeight: 200,
                   // Use the constraints from the LayoutBuilder which
                   // should match the Autocomplete widget's allocated space
                   maxWidth: constraints.maxWidth,
                 ),
                 child: ListView.builder(
                   padding: EdgeInsets.zero,
                   shrinkWrap: true,
                   itemCount: currentOptions.length,
                   itemBuilder: (BuildContext context, int index) {
                     final double option = currentOptions.elementAt(index);
                     return InkWell(
                       onTap: () {
                         // This is called when tapping an item in the list
                         onAutocompleteSelected(option);
                       },
                       child: ListTile(
                         title: Text(_formatDouble(option)),
                       ),
                     );
                   },
                 ),
               ),
                          ),
            );
          },
        
          // --- Selection Logic ---
          // This is called when an option is selected from the list *or*
          // if onFieldSubmitted calls onAutocompleteSelected internally.
          onSelected: (double selection) {
            // Notify the parent widget about the selection
            onSelected(selection);
            // Unfocus the text field after selection
            FocusScope.of(context).unfocus();
          },
        );
      }
    );
  }
}