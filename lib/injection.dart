import 'package:get_it/get_it.dart';
import 'data/repositories/group_repository_impl.dart';
import 'domain/repositories/group_repository.dart';
import 'domain/usecases/group_usecases.dart';
import 'domain/usecases/member_usecases.dart';
import 'presentation/blocs/group_list/group_list_cubit.dart';
import 'presentation/blocs/group_detail/group_detail_cubit.dart';
import 'presentation/blocs/settings/settings_cubit.dart';
import 'core/database/database.dart';

import 'domain/usecases/expense_usecases.dart';
import 'domain/repositories/expense_repository.dart';
import 'data/repositories/expense_repository_impl.dart';

import 'domain/usecases/settlement_usecases.dart';
import 'domain/repositories/settlement_repository.dart';
import 'data/repositories/settlement_repository_impl.dart';

import 'domain/repositories/settings_repository.dart';
import 'data/repositories/settings_repository_impl.dart';

final sl = GetIt.instance;

void init() {
  // Database
  sl.registerLazySingleton<AppDatabase>(() => AppDatabase());

  // Repository
  sl.registerLazySingleton<GroupRepository>(
    () => GroupRepositoryImpl(sl()),
  );
  sl.registerLazySingleton<ExpenseRepository>(
    () => ExpenseRepositoryImpl(sl()),
  );
  sl.registerLazySingleton<SettlementRepository>(
    () => SettlementRepositoryImpl(sl()),
  );
  sl.registerLazySingleton<SettingsRepository>(
    () => SettingsRepositoryImpl(sl()),
  );
  sl.registerLazySingleton<BackupRepository>(
    () => BackupRepositoryImpl(sl()),
  );

  // Use Cases
  sl.registerLazySingleton(() => GetGroups(sl()));
  sl.registerLazySingleton(() => CreateGroup(sl()));
  sl.registerLazySingleton(() => UpdateGroup(sl()));
  sl.registerLazySingleton(() => DeleteGroup(sl()));
  sl.registerLazySingleton(() => GetGroupById(sl()));
  sl.registerLazySingleton(() => SetGroupArchived(sl()));
  sl.registerLazySingleton(() => GetMembers(sl()));
  sl.registerLazySingleton(() => AddMember(sl()));
  sl.registerLazySingleton(() => UpdateMember(sl()));
  sl.registerLazySingleton(() => DeleteMember(sl()));

  sl.registerLazySingleton(() => GetExpensesByGroup(sl()));
  sl.registerLazySingleton(() => AddExpense(sl()));
  sl.registerLazySingleton(() => UpdateExpense(sl()));
  sl.registerLazySingleton(() => DeleteExpense(sl()));

  sl.registerLazySingleton(() => GetSettlementsByGroup(sl()));
  sl.registerLazySingleton(() => AddSettlement(sl()));
  sl.registerLazySingleton(() => DeleteSettlement(sl()));
  sl.registerLazySingleton(() => GetGroupOverview(
        groupRepository: sl(),
        expenseRepository: sl(),
        settlementRepository: sl(),
      ));

  // Blocs/Cubits
  sl.registerLazySingleton(() => SettingsCubit(sl()));
  sl.registerFactory(
    () => GroupListCubit(
      getGroups: sl(),
      createGroupUseCase: sl(),
      updateGroupUseCase: sl(),
      deleteGroupUseCase: sl(),
      setGroupArchivedUseCase: sl(),
      getGroupOverview: sl(),
    ),
  );
  sl.registerFactory(
    () => GroupDetailCubit(
      getGroupOverview: sl(),
      addMemberUseCase: sl(),
      updateMemberUseCase: sl(),
      deleteMemberUseCase: sl(),
      deleteExpenseUseCase: sl(),
      addSettlementUseCase: sl(),
      deleteSettlementUseCase: sl(),
      setGroupArchivedUseCase: sl(),
    ),
  );
}
