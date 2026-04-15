import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/admin_stats_service.dart';

class AdminStatsScreen extends StatefulWidget {
  const AdminStatsScreen({super.key});

  @override
  State<AdminStatsScreen> createState() => _AdminStatsScreenState();
}

class _AdminStatsScreenState extends State<AdminStatsScreen> {
  final AdminStatsService _service = AdminStatsService();
  late Future<AdminStats> _statsFuture;

  @override
  void initState() {
    super.initState();
    _statsFuture = _service.fetchStats();
  }

  void _refresh() {
    setState(() {
      _statsFuture = _service.fetchStats();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: FutureBuilder<AdminStats>(
        future: _statsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 12),
                  Text('Failed to load stats: ${snapshot.error}'),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            );
          }
          final stats = snapshot.data!;
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Platform Statistics',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Refresh',
                      onPressed: _refresh,
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Summary cards
                LayoutBuilder(
                  builder: (context, constraints) {
                    final crossAxisCount = constraints.maxWidth < 600 ? 2 : 4;
                    return GridView.count(
                      crossAxisCount: crossAxisCount,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.5,
                      children: [
                        _SummaryCard(
                          label: 'Active Users',
                          value: stats.activeUsers,
                          icon: Icons.people_outline,
                          color: Colors.deepPurple,
                        ),
                        _SummaryCard(
                          label: 'Blogs Published',
                          value: stats.totalBlogs,
                          icon: Icons.article_outlined,
                          color: Colors.teal,
                        ),
                        _SummaryCard(
                          label: 'Reports Filed',
                          value: stats.totalReports,
                          icon: Icons.flag_outlined,
                          color: Colors.orange,
                        ),
                        _SummaryCard(
                          label: 'Mod Actions',
                          value: stats.totalModActions,
                          icon: Icons.gavel_outlined,
                          color: Colors.red,
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),
                // Moderation actions over time
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Moderation Actions — Last 3 Months',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Actions per week',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Colors.grey),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 200,
                          child: stats.weeklyModStats.isEmpty
                              ? const Center(
                                  child: Text('No moderation activity yet.'))
                              : _buildBarChart(stats.weeklyModStats),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Action type breakdown
                if (stats.actionTypeCounts.isNotEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Actions by Type (Last 3 Months)',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              return constraints.maxWidth < 500
                                  ? Column(
                                      children: [
                                        SizedBox(
                                          height: 200,
                                          child: _buildPieChart(
                                              stats.actionTypeCounts),
                                        ),
                                        const SizedBox(height: 12),
                                        _buildPieLegend(
                                            stats.actionTypeCounts),
                                      ],
                                    )
                                  : Row(
                                      children: [
                                        SizedBox(
                                          width: 200,
                                          height: 200,
                                          child: _buildPieChart(
                                              stats.actionTypeCounts),
                                        ),
                                        const SizedBox(width: 24),
                                        Expanded(
                                            child: _buildPieLegend(
                                                stats.actionTypeCounts)),
                                      ],
                                    );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  static const List<String> _monthAbbr = [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _formatWeek(DateTime date) {
    return '${_monthAbbr[date.month]} ${date.day}';
  }

  static const List<Color> _pieColors = [
    Color(0xFF6750A4),
    Color(0xFF009688),
    Color(0xFFFF9800),
    Color(0xFFF44336),
    Color(0xFF2196F3),
    Color(0xFF4CAF50),
    Color(0xFF9C27B0),
  ];

  Widget _buildBarChart(List<WeeklyModStat> stats) {
    final maxY = stats.fold<double>(
      4,
      (prev, s) => s.count.toDouble() > prev ? s.count.toDouble() + 1 : prev,
    );

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final week = stats[groupIndex].weekStart;
              return BarTooltipItem(
                '${_formatWeek(week)}\n${rod.toY.toInt()} actions',
                const TextStyle(color: Colors.white, fontSize: 12),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                if (value % 1 != 0) return const SizedBox.shrink();
                return Text(
                  value.toInt().toString(),
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= stats.length) {
                  return const SizedBox.shrink();
                }
                // Show label every 2nd bar to avoid overlap
                if (idx % 2 != 0) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _formatWeek(stats[idx].weekStart),
                    style: const TextStyle(fontSize: 9),
                  ),
                );
              },
            ),
          ),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: true),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(stats.length, (i) {
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: stats[i].count.toDouble(),
                color: Theme.of(context).colorScheme.primary,
                width: 10,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildPieChart(Map<String, int> counts) {
    final entries = counts.entries.toList();
    final total = entries.fold<int>(0, (sum, e) => sum + e.value);

    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 32,
        sections: List.generate(entries.length, (i) {
          final pct = total > 0 ? entries[i].value / total * 100 : 0.0;
          return PieChartSectionData(
            color: _pieColors[i % _pieColors.length],
            value: entries[i].value.toDouble(),
            title: '${pct.toStringAsFixed(0)}%',
            radius: 60,
            titleStyle: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          );
        }),
      ),
    );
  }

  Widget _buildPieLegend(Map<String, int> counts) {
    final entries = counts.entries.toList();
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: List.generate(entries.length, (i) {
        final label = _prettifyActionType(entries[i].key);
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: _pieColors[i % _pieColors.length],
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text('$label (${entries[i].value})',
                style: const TextStyle(fontSize: 13)),
          ],
        );
      }),
    );
  }

  String _prettifyActionType(String type) {
    switch (type) {
      case 'ban':
        return 'Ban';
      case 'warn':
        return 'Warn';
      case 'delete_post':
        return 'Delete Post';
      case 'delete_account':
        return 'Delete Account';
      case 'automod_block':
        return 'Automod Block';
      default:
        return type
            .split('_')
            .map((w) => w.isEmpty
                ? ''
                : '${w[0].toUpperCase()}${w.substring(1)}')
            .join(' ');
    }
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const Spacer(),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.bottomLeft,
              child: Text(
                value.toString(),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}
