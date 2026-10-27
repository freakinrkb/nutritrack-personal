import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:opennutritracker/core/presentation/widgets/app_card.dart';
import 'package:opennutritracker/core/styles/app_palette.dart';
import 'package:opennutritracker/core/styles/dimens.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/core/utils/navigation_options.dart';
import 'package:opennutritracker/features/routines/domain/entity/habit_entity.dart';
import 'package:opennutritracker/features/routines/presentation/bloc/routines_bloc.dart';
import 'package:opennutritracker/generated/l10n.dart';

class RoutineHomeCard extends StatefulWidget {
  final RoutinesBloc? bloc;

  const RoutineHomeCard({super.key, this.bloc});

  @override
  State<RoutineHomeCard> createState() => _RoutineHomeCardState();
}

class _RoutineHomeCardState extends State<RoutineHomeCard> {
  late final RoutinesBloc _bloc = widget.bloc ?? locator<RoutinesBloc>();

  @override
  void initState() {
    super.initState();
    if (_bloc.state is RoutinesInitial) {
      _bloc.add(const LoadRoutinesEvent());
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RoutinesBloc, RoutinesState>(
      bloc: _bloc,
      builder: (context, state) {
        final l10n = S.of(context);
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final palette = isDark ? AppPalette.dark : AppPalette.light;
        final accent = Theme.of(context).colorScheme.primary;
        final textTheme = Theme.of(context).textTheme;

        final loaded = state is RoutinesLoaded ? state.day : null;
        final progress = loaded == null
            ? null
            : l10n.routinesProgressLabel(loaded.doneCount, loaded.totalCount);

        return Padding(
          padding: const EdgeInsets.fromLTRB(
            Dimens.spacing16,
            Dimens.spacing8,
            Dimens.spacing16,
            0,
          ),
          child: Semantics(
            identifier: 'home-routine-card',
            container: true,
            child: AppCard(
              padding: const EdgeInsets.all(Dimens.spacing16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.checklist_rounded,
                          size: 20,
                          color: accent,
                        ),
                      ),
                      const SizedBox(width: Dimens.spacing12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.routinesTitle,
                              style: textTheme.titleMedium?.copyWith(
                                color: palette.textStrong,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (progress != null)
                              Text(
                                progress,
                                style: textTheme.bodySmall?.copyWith(
                                  color: palette.textMuted,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Semantics(
                        identifier: 'home-routine-view-all',
                        child: TextButton(
                          onPressed: () => _openRoutines(context),
                          child: Text(l10n.routinesViewAllAction),
                        ),
                      ),
                    ],
                  ),
                  if (state is RoutinesLoading || state is RoutinesInitial) ...[
                    const SizedBox(height: Dimens.spacing12),
                    const LinearProgressIndicator(minHeight: 3),
                  ] else if (state is RoutinesFailure) ...[
                    const SizedBox(height: Dimens.spacing12),
                    Text(
                      l10n.routinesLoadFailed,
                      style: textTheme.bodyMedium?.copyWith(
                        color: palette.textMuted,
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => _bloc.add(const LoadRoutinesEvent()),
                        child: Text(l10n.retryLabel),
                      ),
                    ),
                  ] else if (loaded != null && loaded.isEmpty) ...[
                    const SizedBox(height: Dimens.spacing12),
                    Text(
                      l10n.routinesHomeEmptyBody,
                      style: textTheme.bodyMedium?.copyWith(
                        color: palette.textMuted,
                      ),
                    ),
                    const SizedBox(height: Dimens.spacing8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Semantics(
                        identifier: 'home-routine-add',
                        child: TextButton.icon(
                          onPressed: () => _openRoutines(context),
                          icon: const Icon(Icons.add_rounded),
                          label: Text(l10n.routinesHomeAddAction),
                        ),
                      ),
                    ),
                  ] else if (loaded != null) ...[
                    const SizedBox(height: Dimens.spacing4),
                    for (final habit in loaded.habits.take(3))
                      _HomeHabitRow(
                        habit: habit,
                        palette: palette,
                        onToggle: () => _toggle(habit),
                      ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
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

  void _openRoutines(BuildContext context) {
    Navigator.of(context).pushNamed(NavigationOptions.routinesRoute);
  }
}

class _HomeHabitRow extends StatelessWidget {
  final RoutineHabitEntity habit;
  final AppPalette palette;
  final VoidCallback onToggle;

  const _HomeHabitRow({
    required this.habit,
    required this.palette,
    required this.onToggle,
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

    return Semantics(
      identifier: 'home-routine-toggle-${habit.habit.id}',
      button: true,
      child: InkWell(
        borderRadius: Dimens.borderRadiusS,
        onTap: onToggle,
        child: Row(
          children: [
            Semantics(
              identifier: 'home-routine-check-${habit.habit.id}',
              child: Checkbox(
                value: habit.isDone,
                onChanged: (_) => onToggle(),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    habit.habit.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodyMedium?.copyWith(
                      color: palette.textStrong,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.labelSmall?.copyWith(
                      color: palette.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
