import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

class AdminStats {
  final int activeUsers;
  final int totalBlogs;
  final int totalReports;
  final int totalModActions;
  final List<WeeklyModStat> weeklyModStats;
  final Map<String, int> actionTypeCounts;

  const AdminStats({
    required this.activeUsers,
    required this.totalBlogs,
    required this.totalReports,
    required this.totalModActions,
    required this.weeklyModStats,
    required this.actionTypeCounts,
  });
}

class WeeklyModStat {
  final DateTime weekStart;
  final int count;

  const WeeklyModStat({required this.weekStart, required this.count});
}

class AdminStatsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'default',
  );

  Future<AdminStats> fetchStats() async {
    final now = DateTime.now();
    final threeMonthsAgo = DateTime(now.year, now.month - 3, now.day);

    final results = await Future.wait([
      _firestore
          .collection('users')
          .where('status', isEqualTo: 'active')
          .count()
          .get(),
      _firestore.collection('blogs').count().get(),
      _firestore.collection('reports').count().get(),
      _firestore
          .collection('moderation_logs')
          .where('createdAt',
              isGreaterThanOrEqualTo:
                  Timestamp.fromDate(threeMonthsAgo))
          .get(),
      _firestore.collection('moderation_logs').count().get(),
    ]);

    final activeUsers =
        (results[0] as AggregateQuerySnapshot).count ?? 0;
    final totalBlogs =
        (results[1] as AggregateQuerySnapshot).count ?? 0;
    final totalReports =
        (results[2] as AggregateQuerySnapshot).count ?? 0;

    final logsSnapshot = results[3] as QuerySnapshot<Map<String, dynamic>>;
    final logs = logsSnapshot.docs.map((d) => d.data()).toList();

    // Group by week
    final Map<DateTime, int> weekMap = {};
    final Map<String, int> actionTypeCounts = {};

    for (final log in logs) {
      // Action type counts
      final actionType = log['actionType'] as String? ?? 'unknown';
      actionTypeCounts[actionType] = (actionTypeCounts[actionType] ?? 0) + 1;

      // Week grouping (Monday as week start)
      final Timestamp? ts = log['createdAt'] as Timestamp?;
      if (ts != null) {
        final date = ts.toDate();
        final daysFromMonday = date.weekday - 1;
        final weekStart = DateTime(
          date.year,
          date.month,
          date.day - daysFromMonday,
        );
        weekMap[weekStart] = (weekMap[weekStart] ?? 0) + 1;
      }
    }

    // Build sorted weekly stats covering last 13 weeks (3 months)
    final weeklyModStats = <WeeklyModStat>[];
    for (int weekOffset = 12; weekOffset >= 0; weekOffset--) {
      final daysBack = weekOffset * 7;
      final date = now.subtract(Duration(days: daysBack));
      final daysFromMonday = date.weekday - 1;
      final weekStart = DateTime(
        date.year,
        date.month,
        date.day - daysFromMonday,
      );
      weeklyModStats.add(WeeklyModStat(
        weekStart: weekStart,
        count: weekMap[weekStart] ?? 0,
      ));
    }

    // Deduplicate weeks in case of overlap
    final seen = <DateTime>{};
    final dedupedStats = weeklyModStats
        .where((s) => seen.add(s.weekStart))
        .toList();

    // Total mod actions — all-time count fetched in parallel above
    final totalModActions = (results[4] as AggregateQuerySnapshot).count ?? 0;

    return AdminStats(
      activeUsers: activeUsers,
      totalBlogs: totalBlogs,
      totalReports: totalReports,
      totalModActions: totalModActions,
      weeklyModStats: dedupedStats,
      actionTypeCounts: actionTypeCounts,
    );
  }
}
