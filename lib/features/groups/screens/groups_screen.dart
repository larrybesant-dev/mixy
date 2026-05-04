import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/layout/app_layout.dart';
import '../../../core/theme.dart';
import '../../../shared/widgets/app_page_scaffold.dart';
import '../../../shared/widgets/async_state_view.dart';
import '../../../widgets/brand_ui_kit.dart';
import '../models/group_model.dart';
import '../providers/groups_provider.dart';

class GroupsScreen extends ConsumerWidget {
  final String userId;

  const GroupsScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(groupsProvider);
    final userGroupsAsync = ref.watch(userGroupsProvider(userId));

    return DefaultTabController(
      length: 2,
      child: AppPageScaffold(
        appBar: AppBar(
          title: const MixvyAppBarLogo(fontSize: 20),
          bottom: const TabBar(
            indicatorColor: VelvetNoir.primary,
            labelColor: VelvetNoir.primary,
            unselectedLabelColor: VelvetNoir.onSurfaceVariant,
            indicatorWeight: 2,
            tabs: [
              Tab(text: 'Discover'),
              Tab(text: 'My Groups'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(
                Icons.add_circle_outline,
                color: VelvetNoir.primary,
              ),
              tooltip: 'Create group',
              onPressed: () => context.push('/create-group?userId=$userId'),
            ),
          ],
        ),
        body: TabBarView(
          children: [
            AppAsyncValueView<List<Group>>(
              value: groupsAsync,
              fallbackContext: 'groups',
              isEmpty: (groups) => groups.isEmpty,
              empty: const AppEmptyView(
                icon: Icons.groups_outlined,
                title: 'No groups yet',
              ),
              data: (groups) => ListView.builder(
                padding: EdgeInsets.symmetric(
                  horizontal: context.pageHorizontalPadding,
                  vertical: 12,
                ),
                itemCount: groups.length,
                itemBuilder: (context, index) {
                  final group = groups[index];
                  final isMember = group.isMember(userId);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: VelvetNoir.surfaceContainer,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: VelvetNoir.outlineVariant.withValues(alpha: 0.5),
                      ),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => context.push('/group/${group.id}'),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    group.name,
                                    style: const TextStyle(
                                      color: VelvetNoir.onSurface,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${group.memberCount} members',
                                    style: const TextStyle(
                                      color: VelvetNoir.onSurfaceVariant,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 80,
                              child: ElevatedButton(
                                onPressed: () {
                                  if (isMember) {
                                    ref
                                        .read(groupsControllerProvider)
                                        .leaveGroup(
                                          groupId: group.id,
                                          userId: userId,
                                        );
                                  } else {
                                    ref
                                        .read(groupsControllerProvider)
                                        .joinGroup(
                                          groupId: group.id,
                                          userId: userId,
                                        );
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isMember
                                      ? VelvetNoir.surfaceBright
                                      : VelvetNoir.primaryDim,
                                  foregroundColor: VelvetNoir.onSurface,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                  isMember ? 'Leave' : 'Join',
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            AppAsyncValueView<List<Group>>(
              value: userGroupsAsync,
              fallbackContext: 'your groups',
              isEmpty: (groups) => groups.isEmpty,
              empty: const AppEmptyView(
                icon: Icons.group_work_outlined,
                title: 'You haven\'t joined any groups yet',
              ),
              data: (groups) => ListView.builder(
                padding: EdgeInsets.symmetric(
                  horizontal: context.pageHorizontalPadding,
                  vertical: 12,
                ),
                itemCount: groups.length,
                itemBuilder: (context, index) {
                  final group = groups[index];

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: VelvetNoir.surfaceContainer,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: VelvetNoir.outlineVariant.withValues(alpha: 0.5),
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      title: Text(
                        group.name,
                        style: const TextStyle(
                          color: VelvetNoir.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        '${group.memberCount} members',
                        style: const TextStyle(
                          color: VelvetNoir.onSurfaceVariant,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.chevron_right,
                        color: VelvetNoir.onSurfaceVariant,
                      ),
                      onTap: () => context.push('/group/${group.id}'),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
