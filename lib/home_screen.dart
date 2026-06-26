import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'time_entry_provider.dart';
import 'add_time_entry_screen.dart';
import 'project_management_screen.dart';
import 'task_management_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _formatDuration(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (hours > 0) {
      return '${hours}h ${mins}m';
    }
    return '${mins}m';
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  void _goToAddEntry() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddTimeEntryScreen()),
    );
  }

  /// Deletes the entry, then shows a snackbar confirming the deletion
  /// with an option to undo it by re-adding the same entry.
  void _deleteEntry(TimeEntryProvider provider, TimeEntry entry) {
    provider.deleteTimeEntry(entry.id);

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Time entry deleted'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            provider.addTimeEntry(entry);
          },
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Time Tracker'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'All Entries'),
            Tab(text: 'Grouped by Project'),
          ],
        ),
      ),
      drawer: _buildNavigationDrawer(context),
      body: Consumer<TimeEntryProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return Column(
            children: [
              _SummaryCard(
                totalLabel: _formatDuration(provider.totalMinutesTracked),
                projectCount: provider.projects.length,
                taskCount: provider.tasks.length,
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _AllEntriesTab(
                      provider: provider,
                      formatDuration: _formatDuration,
                      formatDate: _formatDate,
                      onDelete: (entry) => _deleteEntry(provider, entry),
                      onAddPressed: _goToAddEntry,
                    ),
                    _GroupedByProjectTab(
                      provider: provider,
                      formatDuration: _formatDuration,
                      formatDate: _formatDate,
                      onDelete: (entry) => _deleteEntry(provider, entry),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _goToAddEntry,
        icon: const Icon(Icons.add),
        label: const Text('Add Entry'),
      ),
    );
  }

  Widget _buildNavigationDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: Colors.indigo),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Text(
                'Time Tracker',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home_outlined),
            title: const Text('Home'),
            selected: true,
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.folder_outlined),
            title: const Text('Projects'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ProjectManagementScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.checklist_outlined),
            title: const Text('Tasks'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const TaskManagementScreen(),
                ),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.add_circle_outline),
            title: const Text('Add Time Entry'),
            onTap: () {
              Navigator.pop(context);
              _goToAddEntry();
            },
          ),
        ],
      ),
    );
  }
}

/// ---------------------------------------------------------------------
/// TAB 1: ALL ENTRIES (flat, most-recent-first list)
/// ---------------------------------------------------------------------

class _AllEntriesTab extends StatelessWidget {
  final TimeEntryProvider provider;
  final String Function(int) formatDuration;
  final String Function(DateTime) formatDate;
  final void Function(TimeEntry) onDelete;
  final VoidCallback onAddPressed;

  const _AllEntriesTab({
    required this.provider,
    required this.formatDuration,
    required this.formatDate,
    required this.onDelete,
    required this.onAddPressed,
  });

  @override
  Widget build(BuildContext context) {
    final entries = provider.recentTimeEntries;

    if (entries.isEmpty) {
      return _EmptyState(onAddPressed: onAddPressed);
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80, top: 8),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        final project = provider.getProjectById(entry.projectId);
        final task =
            entry.taskId != null ? provider.getTaskById(entry.taskId!) : null;
        return _TimeEntryTile(
          entry: entry,
          projectName: project?.name ?? 'Unknown Project',
          taskTitle: task?.title ?? 'Unknown Task',
          durationLabel: formatDuration(entry.durationMinutes),
          dateLabel: formatDate(entry.date),
          onDelete: () => onDelete(entry),
        );
      },
    );
  }
}

/// ---------------------------------------------------------------------
/// TAB 2: GROUPED BY PROJECT
/// ---------------------------------------------------------------------

class _GroupedByProjectTab extends StatelessWidget {
  final TimeEntryProvider provider;
  final String Function(int) formatDuration;
  final String Function(DateTime) formatDate;
  final void Function(TimeEntry) onDelete;

  const _GroupedByProjectTab({
    required this.provider,
    required this.formatDuration,
    required this.formatDate,
    required this.onDelete,
  });

  /// Builds a mapping of projectId -> list of time entries for that
  /// project. This is the "group-by" logic the grouped tab relies on.
  Map<String, List<TimeEntry>> _groupEntriesByProject(
    List<TimeEntry> entries,
  ) {
    final Map<String, List<TimeEntry>> grouped = {};
    for (final entry in entries) {
      grouped.putIfAbsent(entry.projectId, () => []).add(entry);
    }
    // Sort each project's entries by date, most recent first.
    for (final list in grouped.values) {
      list.sort((a, b) => b.date.compareTo(a.date));
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _groupEntriesByProject(provider.timeEntries);

    if (grouped.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.folder_open_outlined,
                  size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'No entries to group yet',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
      );
    }

    // Order project groups by the project's display order; fall back to
    // "Unknown Project" group last if any orphaned entries exist.
    final projectIds = grouped.keys.toList()
      ..sort((a, b) {
        final pa = provider.getProjectById(a)?.name ?? '';
        final pb = provider.getProjectById(b)?.name ?? '';
        return pa.compareTo(pb);
      });

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80, top: 8),
      itemCount: projectIds.length,
      itemBuilder: (context, index) {
        final projectId = projectIds[index];
        final project = provider.getProjectById(projectId);
        final entriesForProject = grouped[projectId]!;
        final totalMinutes = entriesForProject.fold<int>(
          0,
          (sum, e) => sum + e.durationMinutes,
        );

        return ExpansionTile(
          initiallyExpanded: true,
          title: Text(
            project?.name ?? 'Unknown Project',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            '${entriesForProject.length} entries • '
            '${formatDuration(totalMinutes)} total',
          ),
          children: entriesForProject.map((entry) {
            final task = entry.taskId != null
                ? provider.getTaskById(entry.taskId!)
                : null;
            return _TimeEntryTile(
              entry: entry,
              projectName: project?.name ?? 'Unknown Project',
              taskTitle: task?.title ?? 'Unknown Task',
              durationLabel: formatDuration(entry.durationMinutes),
              dateLabel: formatDate(entry.date),
              showProjectName: false,
              onDelete: () => onDelete(entry),
            );
          }).toList(),
        );
      },
    );
  }
}

/// ---------------------------------------------------------------------
/// SHARED TILE WIDGET (used by both tabs)
/// ---------------------------------------------------------------------

class _TimeEntryTile extends StatelessWidget {
  final TimeEntry entry;
  final String projectName;
  final String taskTitle;
  final String durationLabel;
  final String dateLabel;
  final VoidCallback onDelete;
  final bool showProjectName;

  const _TimeEntryTile({
    required this.entry,
    required this.projectName,
    required this.taskTitle,
    required this.durationLabel,
    required this.dateLabel,
    required this.onDelete,
    this.showProjectName = true,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(entry.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async => true,
      onDismissed: (_) => onDelete(),
      child: ListTile(
        leading: CircleAvatar(child: Text(durationLabel.substring(0, 1))),
        title: Text(showProjectName ? projectName : taskTitle),
        subtitle: Text(
          showProjectName ? '$taskTitle • $dateLabel' : dateLabel,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              durationLabel,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: 'Delete entry',
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------
/// SUPPORTING WIDGETS
/// ---------------------------------------------------------------------

class _SummaryCard extends StatelessWidget {
  final String totalLabel;
  final int projectCount;
  final int taskCount;

  const _SummaryCard({
    required this.totalLabel,
    required this.projectCount,
    required this.taskCount,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Total Time Tracked',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              totalLabel,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _StatChip(
                    icon: Icons.folder_outlined,
                    label: '$projectCount Projects'),
                const SizedBox(width: 12),
                _StatChip(
                    icon: Icons.checklist_outlined, label: '$taskCount Tasks'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StatChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAddPressed;

  const _EmptyState({required this.onAddPressed});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.timer_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No time entries yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the button below to log your first entry.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onAddPressed,
              icon: const Icon(Icons.add),
              label: const Text('Add Time Entry'),
            ),
          ],
        ),
      ),
    );
  }
}
