import 'package:go_router/go_router.dart';
import '../presentation/pages/group_list_page.dart';
import '../presentation/pages/group_detail_page.dart';
import '../presentation/pages/add_expense_page.dart';
import '../presentation/pages/settlement_page.dart';
import '../presentation/pages/statistics_page.dart';
import '../presentation/pages/settings_page.dart';
import '../presentation/pages/archived_groups_page.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const GroupListPage(),
    ),
    GoRoute(
      path: '/group/:id',
      builder: (context, state) {
        final idStr = state.pathParameters['id']!;
        return GroupDetailPage(groupId: int.parse(idStr));
      },
      routes: [
        GoRoute(
          path: 'settlement',
          builder: (context, state) => SettlementPage(groupId: int.parse(state.pathParameters['id']!)),
        ),
        GoRoute(
          path: 'stats',
          builder: (context, state) => StatisticsPage(
            groupId: int.parse(state.pathParameters['id']!),
            initialTab: state.uri.queryParameters['tab'] == 'expenses' ? 1 : 0,
          ),
        ),
      ],
    ),
    GoRoute(
      path: '/add-expense',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        return AddExpensePage(
          group: extra['group'],
          members: extra['members'],
          expenseToEdit: extra['expenseToEdit'],
        );
      },
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsPage(),
    ),
    GoRoute(
      path: '/archived',
      builder: (context, state) => const ArchivedGroupsPage(),
    ),
  ],
);
