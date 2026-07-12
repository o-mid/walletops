import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/rule_models.dart';
import 'cubit/rules_cubit.dart';

Future<void> showRuleFormSheet(
  BuildContext context, {
  AlertRule? existing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(ctx).bottom,
        ),
        child: RuleFormSheet(
          existing: existing,
          cubit: context.read<RulesCubit>(),
        ),
      );
    },
  );
}

class RuleFormSheet extends StatefulWidget {
  const RuleFormSheet({
    super.key,
    required this.cubit,
    this.existing,
  });

  final RulesCubit cubit;
  final AlertRule? existing;

  @override
  State<RuleFormSheet> createState() => _RuleFormSheetState();
}

class _RuleFormSheetState extends State<RuleFormSheet> {
  late final TextEditingController _name;
  late final TextEditingController _threshold;
  late String _eventType;
  late bool _enabled;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _name = TextEditingController(text: existing?.name ?? '');
    _threshold = TextEditingController(
      text: existing?.threshold?.toString() ?? '',
    );
    _eventType = existing?.eventType ?? kEventTypes.first;
    _enabled = existing?.enabled ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _threshold.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                editing ? 'Edit rule' : 'New rule',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Name'),
                maxLength: 80,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 8),
              DropdownMenu<String>(
                initialSelection: _eventType,
                label: const Text('Event type'),
                dropdownMenuEntries: [
                  for (final t in kEventTypes)
                    DropdownMenuEntry(value: t, label: t),
                ],
                onSelected: (v) {
                  if (v != null) {
                    setState(() => _eventType = v);
                  }
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _threshold,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Threshold (optional)',
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Enabled'),
                value: _enabled,
                onChanged: (v) => setState(() => _enabled = v),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () async {
                  if (!_formKey.currentState!.validate()) {
                    return;
                  }
                  final raw = _threshold.text.trim();
                  final threshold =
                      raw.isEmpty ? null : double.tryParse(raw);
                  if (raw.isNotEmpty && threshold == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Threshold must be a number')),
                    );
                    return;
                  }
                  final ok = editing
                      ? await widget.cubit.update(
                          id: widget.existing!.id,
                          name: _name.text.trim(),
                          eventType: _eventType,
                          threshold: threshold,
                          clearThreshold: raw.isEmpty,
                          enabled: _enabled,
                        )
                      : await widget.cubit.create(
                          name: _name.text.trim(),
                          eventType: _eventType,
                          threshold: threshold,
                          enabled: _enabled,
                        );
                  if (ok && context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
                child: Text(editing ? 'Save' : 'Create'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
