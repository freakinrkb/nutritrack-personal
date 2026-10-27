import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:opennutritracker/core/presentation/widgets/app_card.dart';
import 'package:opennutritracker/core/presentation/widgets/empty_hint.dart';
import 'package:opennutritracker/core/presentation/widgets/section_group.dart';
import 'package:opennutritracker/core/styles/app_palette.dart';
import 'package:opennutritracker/core/styles/dimens.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/features/routines/domain/entity/habit_entity.dart';
import 'package:opennutritracker/features/routines/presentation/bloc/routines_bloc.dart';
import 'package:opennutritracker/generated/l10n.dart';

enum _RoutineAction { done, skip, clear, edit, delete }

class RoutinesScreen extends StatefulWidget {
  final RoutinesBloc? bloc;

  const RoutinesScreen({super.key, this.bloc});

  @override
  State<RoutinesScreen> createState() => _RoutinesScreenState();
}

class _RoutinesScreenState extends State<RoutinesScreen> {
  late final RoutinesBloc _bloc = widget.bloc ?? locator<RoutinesBloc>();

  @override
  void initState() {
    super.initState();
    _bloc.add(const LoadRoutinesEvent());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = isDark ? AppPalette.dark : AppPalette.light;
    return Scaffold(
      backgroundColor: palette.canvas,
      appBar: AppBar(
        backgroundColor: palette.canvas,
        title: Text(S.of(context).routinesTitle),
      ),
      floatingActionButton: Semantics(
        identifier: 'routines-add',
        child: FloatingActionButton.extended(
          onPressed: () => _addRoutine(context),
          icon: const Icon(Icons.add_rounded),
          label: Text(S.of(context).routinesHomeAddAction),
        ),
      ),
      body: BlocBuilder<RoutinesBloc, RoutinesState>(
        bloc: _bloc,
        builder: (context, state) {
          if (state is RoutinesInitial || state is RoutinesLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is RoutinesFailure) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(Dimens.spacing24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(S.of(context).routinesLoadFailed),
                    const SizedBox(height: Dimens.spacing8),
                    TextButton(
                      onPressed: () => _bloc.add(const LoadRoutinesEvent()),
                      child: Text(S.of(context).retryLabel),
                    ),
                  ],
                ),
              ),
            );
          }
          final day = (state as RoutinesLoaded).day;
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              Dimens.spacing16,
              Dimens.spacing8,
              Dimens.spacing16,
              96,
            ),
            children: [
              _ProgressCard(
                dateLabel: MaterialLocalizations.of(
                  context,
                ).formatFullDate(day.day),
                done: day.doneCount,
                total: day.totalCount,
                palette: palette,
              ),
              const SizedBox(height: Dimens.spacing16),
              if (day.isEmpty)
                EmptyHint(
                  icon: Icons.checklist_rounded,
                  title: S.of(context).routinesEmptyTitle,
                  subtitle: S.of(context).routinesEmptyBody,
                )
              else
                SectionGroup(
                  palette: palette,
                  tiles: [
                    for (final habit in day.habits)
                      _RoutineTile(
                        habit: habit,
                        palette: palette,
                        onToggle: () => _toggle(habit),
                        onAction: (action) =>
                            _handleAction(context, habit, action),
                      ),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }

  void _toggle(RoutineHabitEntity habit) {
    _bloc.add(
      SetRoutineStatusEvent(
        habit.habit.id,
        habit.isDone ? null : HabitStatus.done,
      ),
    );
  }

  Future<void> _handleAction(
    BuildContext context,
    RoutineHabitEntity habit,
    _RoutineAction action,
  ) async {
    switch (action) {
      case _RoutineAction.done:
        _bloc.add(SetRoutineStatusEvent(habit.habit.id, HabitStatus.done));
        break;
      case _RoutineAction.skip:
        _bloc.add(SetRoutineStatusEvent(habit.habit.id, HabitStatus.skipped));
        break;
      case _RoutineAction.clear:
        _bloc.add(SetRoutineStatusEvent(habit.habit.id, null));
        break;
      case _RoutineAction.edit:
        final name = await _showNameDialog(
          context,
          title: S.of(context).routinesEditTitle,
          initialName: habit.habit.name,
        );
        if (name != null) {
          _bloc.add(UpdateRoutineEvent(habit.habit.id, name));
        }
        break;
      case _RoutineAction.delete:
        final confirmed = await _confirmDelete(context);
        if (confirmed == true) {
          _bloc.add(DeleteRoutineEvent(habit.habit.id));
        }
        break;
    }
  }

  Future<void> _addRoutine(BuildContext context) async {
    final name = await _showNameDialog(
      context,
      title: S.of(context).routinesAddTitle,
    );
    if (name != null) {
      _bloc.add(AddRoutineEvent(name));
    }
  }

  Future<String?> _showNameDialog(
    BuildContext context, {
    required String title,
    String? initialName,
  }) {
    return showDialog<String>(
      context: context,
      builder: (_) =>
          _RoutineNameDialog(title: title, initialName: initialName),
    );
  }

  Future<bool?> _confirmDelete(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final l10n = S.of(dialogContext);
        return AlertDialog(
          shape: Dimens.shapeL,
          title: Text(l10n.routinesDeleteTitle),
          content: Text(l10n.routinesDeleteBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.dialogCancelLabel),
            ),
            Semantics(
              identifier: 'routine-delete-confirm',
              child: TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(dialogContext).colorScheme.error,
                ),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(l10n.routinesDeleteAction),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ProgressCard extends StatelessWidget {
  final String dateLabel;
  final int done;
  final int total;
  final AppPalette palette;

  const _ProgressCard({
    required this.dateLabel,
    required this.done,
    required this.total,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
    final textTheme = Theme.of(context).textTheme;
    final progress = total == 0 ? 0.0 : done / total;
    return AppCard(
      padding: const EdgeInsets.all(Dimens.spacing20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            dateLabel,
            style: textTheme.bodySmall?.copyWith(color: palette.textMuted),
          ),
          const SizedBox(height: Dimens.spacing4),
          Text(
            l10n.routinesProgressLabel(done, total),
            style: textTheme.titleLarge?.copyWith(
              color: palette.textStrong,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: Dimens.spacing12),
          ClipRRect(
            borderRadius: BorderRadius.circular(Dimens.spacing4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: palette.border,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoutineTile extends StatelessWidget {
  final RoutineHabitEntity habit;
  final AppPalette palette;
  final VoidCallback onToggle;
  final ValueChanged<_RoutineAction> onAction;

  const _RoutineTile({
    required this.habit,
    required this.palette,
    required this.onToggle,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
    final textTheme = Theme.of(context).textTheme;
    final status = habit.isDone
        ? l10n.routinesDoneTodayLabel
        : habit.isSkipped
            ? l10n.routinesSkippedTodayLabel
            : null;
    final streak = l10n.routinesStreakLabel(habit.streak);
    final subtitle = status == null ? streak : '$status · $streak';
    final actions = <_RoutineAction>[
      if (!habit.isDone) _RoutineAction.done,
      if (!habit.isSkipped) _RoutineAction.skip,
      if (habit.status != null) _RoutineAction.clear,
      _RoutineAction.edit,
      _RoutineAction.delete,
    ];

    return Semantics(
      identifier: 'routine-tile-${habit.habit.id}',
      container: true,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Dimens.spacing12,
        ),
        leading: Semantics(
          identifier: 'routine-check-${habit.habit.id}',
          child: Checkbox(value: habit.isDone, onChanged: (_) => onToggle()),
        ),
        title: Text(
          habit.habit.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: textTheme.bodyLarge?.copyWith(
            color: palette.textStrong,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: textTheme.bodySmall?.copyWith(color: palette.textMuted),
        ),
        onTap: onToggle,
        trailing: Semantics(
          identifier: 'routine-menu-${habit.habit.id}',
          child: PopupMenuButton<_RoutineAction>(
            key: ValueKey('routine-menu-${habit.habit.id}'),
            tooltip: MaterialLocalizations.of(context).showMenuTooltip,
            onSelected: onAction,
            itemBuilder: (context) => [
              for (final action in actions)
                PopupMenuItem(
                  value: action,
                  child: Row(
                    children: [
                      Icon(_actionIcon(action), size: 20),
                      const SizedBox(width: Dimens.spacing12),
                      Text(_actionLabel(context, action)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _actionIcon(_RoutineAction action) => switch (action) {
        _RoutineAction.done => Icons.check_circle_outline_rounded,
        _RoutineAction.skip => Icons.skip_next_rounded,
        _RoutineAction.clear => Icons.remove_circle_outline_rounded,
        _RoutineAction.edit => Icons.edit_outlined,
        _RoutineAction.delete => Icons.delete_outline_rounded,
      };

  String _actionLabel(BuildContext context, _RoutineAction action) {
    final l10n = S.of(context);
    return switch (action) {
      _RoutineAction.done => l10n.routinesMarkDoneAction,
      _RoutineAction.skip => l10n.routinesSkipTodayAction,
      _RoutineAction.clear => l10n.routinesClearTodayAction,
      _RoutineAction.edit => l10n.routinesEditAction,
      _RoutineAction.delete => l10n.routinesDeleteAction,
    };
  }
}

class _RoutineNameDialog extends StatefulWidget {
  final String title;
  final String? initialName;

  const _RoutineNameDialog({required this.title, this.initialName});

  @override
  State<_RoutineNameDialog> createState() => _RoutineNameDialogState();
}

class _RoutineNameDialogState extends State<_RoutineNameDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialName ?? '',
  );

  bool get _canSave => _controller.text.trim().isNotEmpty;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
    return AlertDialog(
      shape: Dimens.shapeL,
      title: Text(widget.title),
      content: Semantics(
        identifier: 'routine-name-field',
        child: TextField(
          controller: _controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          maxLength: 60,
          decoration: InputDecoration(
            labelText: l10n.routinesNameLabel,
            hintText: l10n.routinesNameHint,
          ),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _submit(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.dialogCancelLabel),
        ),
        Semantics(
          identifier: 'routine-name-save',
          child: TextButton(
            onPressed: _canSave ? _submit : null,
            child: Text(l10n.dialogOKLabel),
          ),
        ),
      ],
    );
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop(name);
  }
}
