import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/data/data_source/remote_search_cache_data_source.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/core/domain/usecase/add_intake_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/add_tracked_day_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_kcal_goal_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_macro_goal_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_tracked_day_usecase.dart';
import 'package:opennutritracker/features/add_meal/data/repository/products_repository.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_portion_entity.dart';
import 'package:opennutritracker/features/meal_detail/presentation/bloc/meal_detail_bloc.dart';
import 'package:opennutritracker/features/meal_detail/presentation/widgets/meal_detail_bottom_sheet.dart';
import 'package:opennutritracker/generated/l10n.dart';

class _FakeAddIntakeUsecase extends Fake implements AddIntakeUsecase {}

class _FakeAddTrackedDayUsecase extends Fake implements AddTrackedDayUsecase {}

class _FakeGetKcalGoalUsecase extends Fake implements GetKcalGoalUsecase {}

class _FakeGetMacroGoalUsecase extends Fake implements GetMacroGoalUsecase {}

class _FakeGetTrackedDayUsecase extends Fake implements GetTrackedDayUsecase {}

class _FakeProductsRepository extends Fake implements ProductsRepository {}

class _FakeRemoteSearchCacheDataSource extends Fake
    implements RemoteSearchCacheDataSource {}

MealDetailBloc _buildBloc() => MealDetailBloc(
      _FakeAddIntakeUsecase(),
      _FakeAddTrackedDayUsecase(),
      _FakeGetKcalGoalUsecase(),
      _FakeGetMacroGoalUsecase(),
      _FakeGetTrackedDayUsecase(),
      _FakeProductsRepository(),
      _FakeRemoteSearchCacheDataSource(),
    );

const _nutriments = MealNutrimentsEntity(
  energyKcal100: 250,
  carbohydrates100: 48,
  fat100: 4,
  proteins100: 8,
  sugars100: 3,
  saturatedFat100: 1,
  fiber100: 2,
);

const _cup = MealPortionEntity(
  label: '1 cup',
  gramWeight: 244,
  localized: false,
);

const _slice = MealPortionEntity(
  label: '1 slice',
  gramWeight: 38,
  localized: false,
);

MealEntity _bread({List<MealPortionEntity> portions = const [_cup, _slice]}) =>
    MealEntity(
      code: 'named-portions-test',
      name: 'Bread',
      url: null,
      mealQuantity: null,
      mealUnit: 'g',
      servingQuantity: null,
      servingUnit: 'g',
      servingSize: '1 cup',
      nutriments: _nutriments,
      source: MealSourceEntity.fdc,
      portions: portions,
    );

Future<void> _pumpSheet(
  WidgetTester tester, {
  required MealEntity product,
  required void Function(String?, String?) onChanged,
  String initialUnit = 'serving',
  Locale locale = const Locale('en'),
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.supportedLocales,
      home: Scaffold(
        body: MealDetailBottomSheet(
          product: product,
          day: DateTime(2026, 10, 25),
          intakeTypeEntity: IntakeTypeEntity.breakfast,
          quantityTextController: TextEditingController(text: '1'),
          mealDetailBloc: _buildBloc(),
          selectedUnit: initialUnit,
          onQuantityOrUnitChanged: onChanged,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openUnitMenu(WidgetTester tester) async {
  await tester.tap(find.byType(DropdownButtonFormField<String>));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('offers every named portion and returns its serving# index', (
    tester,
  ) async {
    String? selectedUnit;

    await _pumpSheet(
      tester,
      product: _bread(),
      onChanged: (_, unit) => selectedUnit = unit,
    );

    await _openUnitMenu(tester);
    expect(find.text('1 cup'), findsWidgets);
    expect(find.text('1 slice'), findsOneWidget);

    await tester.tap(find.text('1 slice'));
    await tester.pumpAndSettle();

    expect(selectedUnit, 'serving#1');
  });

  testWidgets('does not show an unverified English portion to a German reader',
      (
    tester,
  ) async {
    await _pumpSheet(
      tester,
      product: _bread(),
      onChanged: (_, _) {},
      locale: const Locale('de'),
    );

    await _openUnitMenu(tester);
    expect(find.text('Portion 1 (244 g)'), findsWidgets);
    expect(find.text('Portion 2 (38 g)'), findsOneWidget);
    expect(find.text('1 cup'), findsNothing);
    expect(find.text('1 slice'), findsNothing);
  });

  testWidgets('shows a verified localized portion label', (tester) async {
    const portions = [
      MealPortionEntity(
        label: '1 Tasse',
        gramWeight: 244,
        localized: true,
      ),
      MealPortionEntity(
        label: '1 Scheibe',
        gramWeight: 38,
        localized: true,
      ),
    ];

    await _pumpSheet(
      tester,
      product: _bread(portions: portions),
      onChanged: (_, _) {},
      locale: const Locale('de'),
    );

    await _openUnitMenu(tester);
    expect(find.text('1 Tasse'), findsWidgets);
    expect(find.text('1 Scheibe'), findsOneWidget);
  });
}
