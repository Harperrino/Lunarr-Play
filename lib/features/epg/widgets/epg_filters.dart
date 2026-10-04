import 'package:material_ui/material_ui.dart';
import 'package:m3uxtream_player/l10n/l10n.dart';

class EpgFilterOption<T> {
  const EpgFilterOption(this.value, this.label);
  final T value;
  final String label;
}

/// Reusable multi-select picker; guide state stays with the screen adapter.
class EpgFilterButton<T> extends StatelessWidget {
  const EpgFilterButton({
    super.key,
    required this.title,
    required this.options,
    required this.selected,
    required this.onChanged,
  });
  final String title;
  final List<EpgFilterOption<T>> options;
  final Set<T> selected;
  final ValueChanged<Set<T>> onChanged;

  Future<void> _choose(BuildContext context) async {
    final draft = {...selected};
    var query = '';
    final result = await showDialog<Set<T>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final visible = options
              .where(
                (option) =>
                    option.label.toLowerCase().contains(query.toLowerCase()),
              )
              .toList();
          return AlertDialog(
            title: Text(title),
            content: SizedBox(
              width: 440,
              height: 360,
              child: Column(
                children: [
                  TextField(
                    decoration: InputDecoration(
                      labelText: context.l10n.epgFilterSearch,
                      prefixIcon: const Icon(Icons.search_rounded),
                    ),
                    onChanged: (value) => setState(() => query = value),
                  ),
                  Wrap(
                    children: [
                      TextButton(
                        onPressed: () => setState(
                          () => draft.addAll(options.map((e) => e.value)),
                        ),
                        child: Text(context.l10n.epgFilterSelectAll),
                      ),
                      TextButton(
                        onPressed: () => setState(draft.clear),
                        child: Text(context.l10n.epgFilterSelectNone),
                      ),
                    ],
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: visible.length,
                      itemBuilder: (context, index) {
                        final option = visible[index];
                        return CheckboxListTile(
                          title: Text(option.label),
                          value: draft.contains(option.value),
                          onChanged: (checked) => setState(() {
                            if (checked == true) {
                              draft.add(option.value);
                            } else {
                              draft.remove(option.value);
                            }
                          }),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(context.l10n.epgFilterCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, {...draft}),
                child: Text(context.l10n.epgFilterApply),
              ),
            ],
          );
        },
      ),
    );
    if (result != null) onChanged(result);
  }

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: options.isEmpty ? null : () => _choose(context),
    icon: const Icon(Icons.filter_list_rounded, size: 18),
    label: Text(
      context.l10n.epgFilterSelection(
        title,
        options.where((e) => selected.contains(e.value)).length,
        options.length,
      ),
    ),
  );
}
