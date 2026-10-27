import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:opennutritracker/features/routines/domain/entity/habit_entity.dart';
import 'package:opennutritracker/features/routines/domain/usecase/add_habit_usecase.dart';
import 'package:opennutritracker/features/routines/domain/usecase/delete_habit_usecase.dart';
import 'package:opennutritracker/features/routines/domain/usecase/get_routine_day_usecase.dart';
import 'package:opennutritracker/features/routines/domain/usecase/set_habit_status_usecase.dart';
import 'package:opennutritracker/features/routines/domain/usecase/update_habit_usecase.dart';

sealed class RoutinesEvent extends Equatable {
  const RoutinesEvent();

  @override
  List<Object?> get props => [];
}

class LoadRoutinesEvent extends RoutinesEvent {
  const LoadRoutinesEvent();
}

class AddRoutineEvent extends RoutinesEvent {
  final String name;

  const AddRoutineEvent(this.name);

  @override
  List<Object?> get props => [name];
}

class UpdateRoutineEvent extends RoutinesEvent {
  final String id;
  final String name;

  const UpdateRoutineEvent(this.id, this.name);

  @override
  List<Object?> get props => [id, name];
}

class DeleteRoutineEvent extends RoutinesEvent {
  final String id;

  const DeleteRoutineEvent(this.id);

  @override
  List<Object?> get props => [id];
}

class SetRoutineStatusEvent extends RoutinesEvent {
  final String id;
  final HabitStatus? status;

  const SetRoutineStatusEvent(this.id, this.status);

  @override
  List<Object?> get props => [id, status];
}

sealed class RoutinesState extends Equatable {
  const RoutinesState();

  @override
  List<Object?> get props => [];
}

class RoutinesInitial extends RoutinesState {
  const RoutinesInitial();
}

class RoutinesLoading extends RoutinesState {
  const RoutinesLoading();
}

class RoutinesLoaded extends RoutinesState {
  final RoutineDayEntity day;

  const RoutinesLoaded(this.day);

  @override
  List<Object?> get props => [day];
}

class RoutinesFailure extends RoutinesState {
  const RoutinesFailure();
}

class RoutinesBloc extends Bloc<RoutinesEvent, RoutinesState> {
  final GetRoutineDayUsecase _getRoutineDay;
  final AddHabitUsecase _addHabit;
  final UpdateHabitUsecase _updateHabit;
  final DeleteHabitUsecase _deleteHabit;
  final SetHabitStatusUsecase _setHabitStatus;

  RoutinesBloc(
    this._getRoutineDay,
    this._addHabit,
    this._updateHabit,
    this._deleteHabit,
    this._setHabitStatus,
  ) : super(const RoutinesInitial()) {
    on<LoadRoutinesEvent>(_onLoad, transformer: sequential());
    on<AddRoutineEvent>(_onAdd, transformer: sequential());
    on<UpdateRoutineEvent>(_onUpdate, transformer: sequential());
    on<DeleteRoutineEvent>(_onDelete, transformer: sequential());
    on<SetRoutineStatusEvent>(_onSetStatus, transformer: sequential());
  }

  Future<void> _onLoad(
    LoadRoutinesEvent event,
    Emitter<RoutinesState> emit,
  ) async {
    if (state is! RoutinesLoaded) {
      emit(const RoutinesLoading());
    }
    await _reload(emit);
  }

  Future<void> _onAdd(
    AddRoutineEvent event,
    Emitter<RoutinesState> emit,
  ) async {
    try {
      await _addHabit(event.name);
      await _reload(emit);
    } catch (_) {
      emit(const RoutinesFailure());
    }
  }

  Future<void> _onUpdate(
    UpdateRoutineEvent event,
    Emitter<RoutinesState> emit,
  ) async {
    try {
      await _updateHabit(event.id, event.name);
      await _reload(emit);
    } catch (_) {
      emit(const RoutinesFailure());
    }
  }

  Future<void> _onDelete(
    DeleteRoutineEvent event,
    Emitter<RoutinesState> emit,
  ) async {
    try {
      await _deleteHabit(event.id);
      await _reload(emit);
    } catch (_) {
      emit(const RoutinesFailure());
    }
  }

  Future<void> _onSetStatus(
    SetRoutineStatusEvent event,
    Emitter<RoutinesState> emit,
  ) async {
    try {
      await _setHabitStatus(event.id, event.status);
      await _reload(emit);
    } catch (_) {
      emit(const RoutinesFailure());
    }
  }

  Future<void> _reload(Emitter<RoutinesState> emit) async {
    try {
      final day = await _getRoutineDay();
      emit(RoutinesLoaded(day));
    } catch (_) {
      emit(const RoutinesFailure());
    }
  }
}
