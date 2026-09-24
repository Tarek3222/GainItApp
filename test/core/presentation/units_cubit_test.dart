import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainit/core/domain/entities/enums.dart';
import 'package:gainit/core/domain/usecases/watch_unit_system_use_case.dart';
import 'package:gainit/core/presentation/units/units_cubit.dart';
import 'package:gainit/core/result/api_result.dart';
import 'package:gainit/core/result/failures.dart';
import 'package:mocktail/mocktail.dart';

class _MockWatchUnits extends Mock implements WatchUnitSystemUseCase {}

void main() {
  late _MockWatchUnits watch;
  late StreamController<ApiResult<UnitSystem>> source;

  setUp(() {
    watch = _MockWatchUnits();
    source = StreamController<ApiResult<UnitSystem>>.broadcast();
    when(() => watch()).thenAnswer((_) => source.stream);
  });

  tearDown(() => source.close());

  test('starts metric before anything is read', () {
    expect(UnitsCubit(watch).state, UnitSystem.metric);
  });

  blocTest<UnitsCubit, UnitSystem>(
    'follows the saved unit and keeps it when a read fails',
    build: () => UnitsCubit(watch),
    act: (cubit) async {
      cubit.start();
      source
        ..add(const ApiSuccess(UnitSystem.imperial))
        ..add(const ApiFailure(StorageFailure()));
      await pumpEventQueue();
    },
    expect: () => [UnitSystem.imperial],
  );

  test('closing stops listening', () async {
    final cubit = UnitsCubit(watch)..start();
    await pumpEventQueue();
    expect(source.hasListener, isTrue);

    await cubit.close();

    expect(source.hasListener, isFalse);
  });
}
