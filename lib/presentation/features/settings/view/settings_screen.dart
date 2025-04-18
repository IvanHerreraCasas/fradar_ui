import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fradar_ui/domain/repositories/radproc_repository.dart';
import 'package:fradar_ui/presentation/features/settings/bloc/settings_bloc.dart';
import 'package:fradar_ui/presentation/features/settings/bloc/settings_event.dart';
import 'package:fradar_ui/presentation/features/settings/bloc/settings_state.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      // Create the Bloc, inject the repository, and trigger initial load
      create:
          (context) =>
              SettingsBloc(radprocRepository: context.read<RadprocRepository>())
                ..add(LoadSettings()), // Trigger initial load
      child: const SettingsView(),
    );
  }
}

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  // Controller to manage the text field
  final TextEditingController _urlController = TextEditingController();

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<SettingsBloc, SettingsState>(
      // Listen for state changes to show Snackbars (side effects)
      listener: (context, state) {
        if (state.status == SettingsStatus.success) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(content: Text('Settings saved successfully!')),
            );
        } else if (state.status == SettingsStatus.failure &&
            state.errorMessage != null) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text('Error: ${state.errorMessage}'),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
        }

        // Update text field controller only when loaded or saved successfully
        // to avoid conflicts while user is typing
        if (state.status == SettingsStatus.loaded ||
            state.status == SettingsStatus.success) {
          if (_urlController.text != state.apiUrl) {
            _urlController.text = state.apiUrl;
          }
        }
      },
      child: Scaffold(
        // Add Scaffold for AppBar and body structure
        appBar: AppBar(
          title: const Text('Settings'),
          elevation: 0, // Flat app bar
          backgroundColor: Colors.transparent, // Inherit background
          foregroundColor: Theme.of(context).textTheme.titleLarge?.color,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: BlocBuilder<SettingsBloc, SettingsState>(
            builder: (context, state) {
              bool isLoading =
                  state.status == SettingsStatus.loading ||
                  state.status == SettingsStatus.saving;

              // Disable input while loading/saving
              final isInteractionDisabled = isLoading;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'RadProc API Base URL',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _urlController,
                    enabled: !isInteractionDisabled,
                    decoration: InputDecoration(
                      hintText: 'e.g., http://192.168.1.100:8000/api/v1',
                      border: const OutlineInputBorder(),
                      // Show progress indicator in the text field while loading/saving
                      suffixIcon:
                          isLoading
                              ? const Padding(
                                padding: EdgeInsets.all(8.0),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.0,
                                ),
                              )
                              : null,
                    ),
                    keyboardType: TextInputType.url,
                    onChanged: (value) {
                      // Notify the Bloc that the text changed
                      context.read<SettingsBloc>().add(ApiUrlChanged(value));
                    },
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    // Disable button while loading/saving or if not editing
                    onPressed:
                        (state.status == SettingsStatus.editing &&
                                !isInteractionDisabled)
                            ? () => context.read<SettingsBloc>().add(
                              SaveSettingsClicked(),
                            )
                            : null,
                    child:
                        isLoading
                            ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.0,
                                color: Colors.white,
                              ),
                            )
                            : const Text('Save Settings'),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
