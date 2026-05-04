import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mixvy/core/theme.dart';

enum _StitchFamily { all, discovery, live, messaging, profile, brand, system }

class _StitchEntry {
  const _StitchEntry({
    required this.slug,
    required this.title,
    required this.family,
    required this.summary,
    required this.platforms,
    this.hasHtml = true,
    this.hasImage = true,
  });

  final String slug;
  final String title;
  final _StitchFamily family;
  final String summary;
  final List<String> platforms;
  final bool hasHtml;
  final bool hasImage;

  String get relativePath => 'lib/stitch_ui/$slug';
}

const List<_StitchEntry> _stitches = <_StitchEntry>[
  _StitchEntry(
    slug: 'after_dark_entry_desktop',
    title: 'After Dark Entry',
    family: _StitchFamily.brand,
    summary: 'Desktop gateway concept for a dramatic first-touch experience.',
    platforms: <String>['Desktop'],
  ),
  _StitchEntry(
    slug: 'after_dark_isolation_kinetic_noir',
    title: 'After Dark Isolation',
    family: _StitchFamily.brand,
    summary: 'Kinetic noir concept built around mood, spotlight, and tension.',
    platforms: <String>['Web', 'Desktop'],
  ),
  _StitchEntry(
    slug: 'home_discovery_feed',
    title: 'Home Discovery Feed',
    family: _StitchFamily.discovery,
    summary: 'Baseline discovery feed pattern for rooms, people, and energy.',
    platforms: <String>['Mobile'],
  ),
  _StitchEntry(
    slug: 'home_discovery_feed_gold_edition',
    title: 'Home Discovery Gold Edition',
    family: _StitchFamily.discovery,
    summary: 'Premium gold-forward variant for the discovery surface.',
    platforms: <String>['Mobile'],
  ),
  _StitchEntry(
    slug: 'home_feed_desktop',
    title: 'Home Feed Desktop',
    family: _StitchFamily.discovery,
    summary: 'Desktop feed layout with broader scanning and heavier modules.',
    platforms: <String>['Desktop'],
  ),
  _StitchEntry(
    slug: 'home_feed_kinetic_noir',
    title: 'Home Feed Kinetic Noir',
    family: _StitchFamily.discovery,
    summary: 'Noir-styled feed exploration with motion-heavy emphasis.',
    platforms: <String>['Web', 'Desktop'],
  ),
  _StitchEntry(
    slug: 'home_feed_mobile',
    title: 'Home Feed Mobile',
    family: _StitchFamily.discovery,
    summary: 'Compact mobile home feed tuned for quick browsing.',
    platforms: <String>['Mobile'],
  ),
  _StitchEntry(
    slug: 'live_room_interior_desktop',
    title: 'Live Room Interior Desktop',
    family: _StitchFamily.live,
    summary:
        'Interior room treatment focused on host framing and stage presence.',
    platforms: <String>['Desktop'],
  ),
  _StitchEntry(
    slug: 'live_room_kinetic_noir',
    title: 'Live Room Kinetic Noir',
    family: _StitchFamily.live,
    summary: 'Experimental room interior with cinematic motion cues.',
    platforms: <String>['Web', 'Desktop'],
  ),
  _StitchEntry(
    slug: 'live_room_page',
    title: 'Live Room Page',
    family: _StitchFamily.live,
    summary: 'Core room page concept for speaker stage and room chrome.',
    platforms: <String>['Mobile'],
  ),
  _StitchEntry(
    slug: 'live_room_page_gold_edition',
    title: 'Live Room Gold Edition',
    family: _StitchFamily.live,
    summary: 'Luxury variant of the room page with brighter premium accents.',
    platforms: <String>['Mobile'],
  ),
  _StitchEntry(
    slug: 'live_rooms_hub_desktop',
    title: 'Live Rooms Hub Desktop',
    family: _StitchFamily.live,
    summary: 'Desktop aggregation view for jumping between active rooms.',
    platforms: <String>['Desktop'],
  ),
  _StitchEntry(
    slug: 'live_rooms_mobile',
    title: 'Live Rooms Mobile',
    family: _StitchFamily.live,
    summary: 'Mobile-first room hub with stacked room discovery.',
    platforms: <String>['Mobile'],
  ),
  _StitchEntry(
    slug: 'messaging_dm_system',
    title: 'Messaging DM System',
    family: _StitchFamily.messaging,
    summary: 'Direct messaging system concept for everyday chat flows.',
    platforms: <String>['Mobile', 'Desktop'],
  ),
  _StitchEntry(
    slug: 'messaging_gold_edition',
    title: 'Messaging Gold Edition',
    family: _StitchFamily.messaging,
    summary: 'Premium messaging treatment with a more opulent frame.',
    platforms: <String>['Mobile'],
  ),
  _StitchEntry(
    slug: 'messaging_system_kinetic_noir',
    title: 'Messaging Kinetic Noir',
    family: _StitchFamily.messaging,
    summary: 'Kinetic noir messaging exploration with deeper contrast.',
    platforms: <String>['Web', 'Desktop'],
  ),
  _StitchEntry(
    slug: 'messaging_whispers_desktop',
    title: 'Messaging Whispers Desktop',
    family: _StitchFamily.messaging,
    summary: 'Desktop whisper concept for low-friction private chat.',
    platforms: <String>['Desktop'],
  ),
  _StitchEntry(
    slug: 'mixvy_adult_lounge_mode',
    title: 'Adult Lounge Mode',
    family: _StitchFamily.brand,
    summary: 'High-intent lounge concept built around intimacy and control.',
    platforms: <String>['Mobile', 'Desktop'],
  ),
  _StitchEntry(
    slug: 'mixvy_gateway_mode_selection',
    title: 'Gateway Mode Selection',
    family: _StitchFamily.system,
    summary: 'Mode switcher concept that frames the product entry decision.',
    platforms: <String>['Mobile', 'Desktop'],
  ),
  _StitchEntry(
    slug: 'mixvy_speed_dating_mode',
    title: 'Speed Dating Mode',
    family: _StitchFamily.discovery,
    summary: 'Swipe-led speed dating concept with energetic live context.',
    platforms: <String>['Mobile'],
  ),
  _StitchEntry(
    slug: 'myspace_profile_desktop',
    title: 'Myspace Profile Desktop',
    family: _StitchFamily.profile,
    summary: 'Desktop profile direction leaning into expressive nostalgia.',
    platforms: <String>['Desktop'],
  ),
  _StitchEntry(
    slug: 'myspace_profile_mobile',
    title: 'Myspace Profile Mobile',
    family: _StitchFamily.profile,
    summary: 'Mobile adaptation of the profile nostalgia concept.',
    platforms: <String>['Mobile'],
  ),
  _StitchEntry(
    slug: 'profile_page',
    title: 'Profile Page',
    family: _StitchFamily.profile,
    summary: 'Core profile concept centered on identity and social proof.',
    platforms: <String>['Mobile'],
  ),
  _StitchEntry(
    slug: 'profile_page_gold_edition',
    title: 'Profile Gold Edition',
    family: _StitchFamily.profile,
    summary: 'Luxury profile variant with stronger premium framing.',
    platforms: <String>['Mobile'],
  ),
  _StitchEntry(
    slug: 'search_page',
    title: 'Search Page',
    family: _StitchFamily.discovery,
    summary: 'Search and browse exploration surface for people and rooms.',
    platforms: <String>['Mobile'],
  ),
  _StitchEntry(
    slug: 'search_page_gold_edition',
    title: 'Search Gold Edition',
    family: _StitchFamily.discovery,
    summary: 'Premium search variant with heavier gold treatment.',
    platforms: <String>['Mobile'],
  ),
  _StitchEntry(
    slug: 'speed_dating_kinetic_noir',
    title: 'Speed Dating Kinetic Noir',
    family: _StitchFamily.discovery,
    summary: 'Noir exploration of the speed dating loop and action stack.',
    platforms: <String>['Web', 'Desktop'],
  ),
  _StitchEntry(
    slug: 'speed_dating_mobile',
    title: 'Speed Dating Mobile',
    family: _StitchFamily.discovery,
    summary: 'Mobile swipe stack concept with live participation framing.',
    platforms: <String>['Mobile'],
  ),
  _StitchEntry(
    slug: 'new_logo.png_1',
    title: 'Logo Exploration 1',
    family: _StitchFamily.brand,
    summary: 'Image-only logo exploration artifact.',
    platforms: <String>['Brand'],
    hasHtml: false,
    hasImage: true,
  ),
  _StitchEntry(
    slug: 'new_logo.png_2',
    title: 'Logo Exploration 2',
    family: _StitchFamily.brand,
    summary: 'Second image-only logo exploration artifact.',
    platforms: <String>['Brand'],
    hasHtml: false,
    hasImage: true,
  ),
];

class StitchPrototypeViewer extends StatefulWidget {
  const StitchPrototypeViewer({super.key});

  @override
  State<StitchPrototypeViewer> createState() => _StitchPrototypeViewerState();
}

class _StitchPrototypeViewerState extends State<StitchPrototypeViewer> {
  final TextEditingController _searchController = TextEditingController();
  _StitchFamily _selectedFamily = _StitchFamily.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<_StitchEntry> get _filteredStitches {
    final query = _searchController.text.trim().toLowerCase();
    return _stitches
        .where((_StitchEntry stitch) {
          final familyMatches =
              _selectedFamily == _StitchFamily.all ||
              stitch.family == _selectedFamily;
          if (!familyMatches) {
            return false;
          }

          if (query.isEmpty) {
            return true;
          }

          final haystack = <String>[
            stitch.title,
            stitch.slug,
            stitch.summary,
            ...stitch.platforms,
            _familyLabel(stitch.family),
          ].join(' ').toLowerCase();

          return haystack.contains(query);
        })
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stitches = _filteredStitches;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              VelvetNoir.surfaceLow,
              VelvetNoir.surface,
              Color(0xFF120B0D),
            ],
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            slivers: <Widget>[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _HeroPanel(
                        totalCount: _stitches.length,
                        filteredCount: stitches.length,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Stitch Catalog',
                        style: theme.textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Raw stitch concepts live under lib/stitch_ui as HTML and PNG artifacts. This viewer keeps the current app entrypoint useful on web without depending on local file access.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: VelvetNoir.onSurfaceVariant,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        style: theme.textTheme.bodyLarge,
                        decoration: InputDecoration(
                          hintText: 'Search stitches, families, or platforms',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: _searchController.text.isEmpty
                              ? null
                              : IconButton(
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {});
                                  },
                                  icon: const Icon(Icons.close_rounded),
                                ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: _StitchFamily.values
                            .map((_StitchFamily family) {
                              final selected = _selectedFamily == family;
                              return FilterChip(
                                selected: selected,
                                label: Text(_familyLabel(family)),
                                onSelected: (_) {
                                  setState(() {
                                    _selectedFamily = family;
                                  });
                                },
                                selectedColor: VelvetNoir.primary.withValues(
                                  alpha: 0.16,
                                ),
                                checkmarkColor: VelvetNoir.primary,
                                labelStyle: theme.textTheme.labelLarge
                                    ?.copyWith(
                                      color: selected
                                          ? VelvetNoir.primary
                                          : VelvetNoir.onSurface,
                                    ),
                                side: BorderSide(
                                  color: selected
                                      ? VelvetNoir.primary.withValues(
                                          alpha: 0.45,
                                        )
                                      : VelvetNoir.outlineVariant,
                                ),
                                backgroundColor: VelvetNoir.surfaceHigh,
                              );
                            })
                            .toList(growable: false),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
              if (stitches.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            Icons.auto_awesome_mosaic_rounded,
                            size: 40,
                            color: VelvetNoir.primary.withValues(alpha: 0.85),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'No stitches match the current filter.',
                            style: theme.textTheme.titleLarge,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Try a broader search term or switch to a different family.',
                            style: theme.textTheme.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                  sliver: SliverLayoutBuilder(
                    builder: (BuildContext context, constraints) {
                      final width = constraints.crossAxisExtent;
                      final crossAxisCount = width >= 1200
                          ? 3
                          : width >= 760
                          ? 2
                          : 1;

                      return SliverGrid(
                        delegate: SliverChildBuilderDelegate((
                          BuildContext context,
                          int index,
                        ) {
                          final stitch = stitches[index];
                          return _StitchCard(
                            stitch: stitch,
                            onCopyPath: () =>
                                _copyPath(context, stitch.relativePath),
                          );
                        }, childCount: stitches.length),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          childAspectRatio: crossAxisCount == 1 ? 1.68 : 1.28,
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _copyPath(BuildContext context, String path) async {
    await Clipboard.setData(ClipboardData(text: path));
    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Copied $path')));
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({required this.totalCount, required this.filteredCount});

  final int totalCount;
  final int filteredCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFF2A1E22),
            Color(0xFF161012),
            Color(0xFF0F0B0D),
          ],
        ),
        border: Border.all(
          color: VelvetNoir.outlineVariant.withValues(alpha: 0.7),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: VelvetNoir.secondaryBright.withValues(alpha: 0.16),
            blurRadius: 36,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: VelvetNoir.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'Velvet Noir Stitch Workspace',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: VelvetNoir.primary,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Design artifacts, organized for fast triage.',
              style: theme.textTheme.displayMedium?.copyWith(height: 1.08),
            ),
            const SizedBox(height: 10),
            Text(
              'This screen indexes the stitch concepts already sitting in the repo so you can scan what exists before deciding which artifact to wire into real Flutter surfaces.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: VelvetNoir.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: <Widget>[
                Expanded(
                  child: _MetricTile(label: 'Visible', value: '$filteredCount'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricTile(label: 'Total', value: '$totalCount'),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: _MetricTile(label: 'Sources', value: 'HTML + PNG'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: VelvetNoir.surface.withValues(alpha: 0.56),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: VelvetNoir.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: VelvetNoir.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: VelvetNoir.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _StitchCard extends StatelessWidget {
  const _StitchCard({required this.stitch, required this.onCopyPath});

  final _StitchEntry stitch;
  final VoidCallback onCopyPath;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[VelvetNoir.surfaceHigh, VelvetNoir.surfaceContainer],
        ),
        border: Border.all(
          color: VelvetNoir.outlineVariant.withValues(alpha: 0.72),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        stitch.title,
                        style: theme.textTheme.titleLarge,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        stitch.slug,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: VelvetNoir.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: VelvetNoir.secondary.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    _familyLabel(stitch.family),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: VelvetNoir.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              stitch.summary,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: stitch.platforms
                  .map((String platform) {
                    return _Badge(label: platform, accent: VelvetNoir.primary);
                  })
                  .toList(growable: false),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _Badge(
                  label: stitch.hasHtml ? 'HTML source' : 'No HTML',
                  accent: stitch.hasHtml
                      ? VelvetNoir.secondaryBright
                      : VelvetNoir.onSurfaceVariant,
                ),
                _Badge(
                  label: stitch.hasImage ? 'PNG preview' : 'No PNG',
                  accent: stitch.hasImage
                      ? VelvetNoir.primary
                      : VelvetNoir.onSurfaceVariant,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: VelvetNoir.surface.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      stitch.relativePath,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: VelvetNoir.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    onPressed: onCopyPath,
                    style: IconButton.styleFrom(
                      backgroundColor: VelvetNoir.primary.withValues(
                        alpha: 0.14,
                      ),
                      foregroundColor: VelvetNoir.primary,
                    ),
                    icon: const Icon(Icons.content_copy_rounded, size: 18),
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

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.accent});

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.34)),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(color: accent),
      ),
    );
  }
}

String _familyLabel(_StitchFamily family) {
  switch (family) {
    case _StitchFamily.all:
      return 'All';
    case _StitchFamily.discovery:
      return 'Discovery';
    case _StitchFamily.live:
      return 'Live';
    case _StitchFamily.messaging:
      return 'Messaging';
    case _StitchFamily.profile:
      return 'Profile';
    case _StitchFamily.brand:
      return 'Brand';
    case _StitchFamily.system:
      return 'System';
  }
}
