import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/services.dart';
import '../../core/theme.dart';
import '../../models/movie.dart';
import '../../widgets/common.dart';
import '../../widgets/poster.dart';
import '../booking/show_selection_screen.dart';
import '../movie_detail/movie_detail_screen.dart';
import '../shell/main_shell.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<_HomeData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_HomeData> _load() async {
    final catalog = context.read<AppServices>().catalog;
    final results = await Future.wait([
      catalog.trending(),
      catalog.movies(),
      catalog.upcoming(),
    ]);
    final trending = results[0];
    final nowPlaying = results[1];
    final upcoming = results[2];
    return _HomeData(
      spotlight: trending.isNotEmpty ? trending : nowPlaying.take(5).toList(),
      trending: nowPlaying,
      upcoming: upcoming,
    );
  }

  Future<void> _refresh() async {
    final data = await _load();
    if (mounted) setState(() => _future = Future.value(data));
  }

  void _openMovie(Movie m) => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MovieDetailScreen(movieId: m.id, preview: m),
        ),
      );

  void _book(Movie m) => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ShowSelectionScreen(movie: m)),
      );

  void _toSearch() => MainShell.of(context)?.goToTab(1);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        title: Row(
          children: [
            const Icon(Icons.location_on, color: AppColors.primary, size: 26),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text('Bengaluru',
                          style: TextStyle(
                              color: AppColors.onSurface,
                              fontSize: 16,
                              fontWeight: FontWeight.w700)),
                      Icon(Icons.expand_more,
                          size: 18, color: AppColors.onSurfaceVariant),
                    ],
                  ),
                  const Text('Karnataka, India',
                      style: TextStyle(
                          color: AppColors.onSurfaceVariant, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.outlineVariant),
        ),
      ),
      body: FutureBuilder<_HomeData>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const _HomeSkeleton();
          }
          if (snap.hasError) {
            return StateMessage(
              icon: Icons.cloud_off_rounded,
              title: 'Could not load movies',
              subtitle: '${snap.error}',
              onRetry: _refresh,
            );
          }
          final data = snap.data!;
          return RefreshIndicator(
            color: AppColors.primary,
            backgroundColor: AppColors.surfaceContainerHigh,
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.only(top: 16, bottom: 110),
              children: [
                _SearchPill(onTap: _toSearch),
                const SizedBox(height: 24),
                if (data.spotlight.isNotEmpty)
                  _SpotlightCarousel(
                    movies: data.spotlight,
                    onBook: _book,
                    onOpen: _openMovie,
                  ),
                if (data.trending.isNotEmpty)
                  _TrendingRail(movies: data.trending, onOpen: _openMovie),
                if (data.upcoming.isNotEmpty)
                  _ComingSoon(movies: data.upcoming, onOpen: _openMovie),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HomeData {
  _HomeData({required this.spotlight, required this.trending, required this.upcoming});
  final List<Movie> spotlight;
  final List<Movie> trending;
  final List<Movie> upcoming;
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Text(title, style: Theme.of(context).textTheme.titleLarge),
    );
  }
}

//Glassmorphic search field that hands off to the Search tab.
class _SearchPill extends StatelessWidget {
  const _SearchPill({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: onTap,
        child: GlassPanel(
          radius: 16,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          borderColor: AppColors.outlineVariant.withValues(alpha: 0.4),
          child: Row(
            children: const [
              Icon(Icons.search, color: AppColors.onSurfaceVariant),
              SizedBox(width: 12),
              Text('Search movies, theaters…',
                  style: TextStyle(color: AppColors.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}

//Snap carousel of marquee films with pagination dots.
class _SpotlightCarousel extends StatefulWidget {
  const _SpotlightCarousel({
    required this.movies,
    required this.onBook,
    required this.onOpen,
  });
  final List<Movie> movies;
  final ValueChanged<Movie> onBook;
  final ValueChanged<Movie> onOpen;
  @override
  State<_SpotlightCarousel> createState() => _SpotlightCarouselState();
}

class _SpotlightCarouselState extends State<_SpotlightCarousel> {
  //Lower fraction → neighbouring cards peek on both sides.
  late final PageController _controller = PageController(viewportFraction: 0.8);
  int _page = 0;
  Timer? _autoRotate;

  @override
  void initState() {
    super.initState();
    if (widget.movies.length > 1) {
      _autoRotate = Timer.periodic(const Duration(seconds: 7), (_) {
        if (!_controller.hasClients) return;
        final next = (_page + 1) % widget.movies.length;
        _controller.animateToPage(
          next,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
        );
      });
    }
  }

  @override
  void dispose() {
    _autoRotate?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('Now Showing'),
          SizedBox(
            height: 470,
            child: PageView.builder(
              controller: _controller,
              itemCount: widget.movies.length,
              onPageChanged: (i) => setState(() => _page = i),
              //The focused card sits at full size; neighbours scale down so the
              //front card reads bigger than the ones behind it.
              itemBuilder: (_, i) => AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  var scale = i == _page ? 1.0 : 0.85;
                  if (_controller.hasClients &&
                      _controller.position.haveDimensions) {
                    final page = _controller.page ?? _page.toDouble();
                    scale = (1 - (page - i).abs() * 0.16).clamp(0.85, 1.0);
                  }
                  return Transform.scale(scale: scale, child: child);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: _SpotlightCard(
                    movie: widget.movies[i],
                    onBook: () => widget.onBook(widget.movies[i]),
                    onOpen: () => widget.onOpen(widget.movies[i]),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < widget.movies.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _page ? 22 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i == _page ? AppColors.primary : AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SpotlightCard extends StatelessWidget {
  const _SpotlightCard({
    required this.movie,
    required this.onBook,
    required this.onOpen,
  });
  final Movie movie;
  final VoidCallback onBook;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onOpen,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            PosterImage(url: movie.backdropUrl ?? movie.posterUrl),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [AppColors.surface, Color(0x99121414), Colors.transparent],
                ),
              ),
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 22,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(movie.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.displayLarge),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final g in movie.genres.take(3)) _GenreChip(g),
                    ],
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: onBook,
                      child: const Text('Book Tickets'),
                    ),
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

class _GenreChip extends StatelessWidget {
  const _GenreChip(this.label);
  final String label;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.7)),
      ),
      child: Text(label,
          style: const TextStyle(color: AppColors.onSurfaceVariant, fontSize: 12)),
    );
  }
}

//Horizontal poster rail with the title + genre beneath each poster.
class _TrendingRail extends StatelessWidget {
  const _TrendingRail({required this.movies, required this.onOpen});
  final List<Movie> movies;
  final ValueChanged<Movie> onOpen;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('Trending Now'),
          SizedBox(
            height: 252,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: movies.length,
              separatorBuilder: (_, _) => const SizedBox(width: 14),
              itemBuilder: (_, i) => _PosterTile(
                movie: movies[i],
                onTap: () => onOpen(movies[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PosterTile extends StatelessWidget {
  const _PosterTile({required this.movie, required this.onTap});
  final Movie movie;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 130,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.button),
              child: AspectRatio(
                aspectRatio: 2 / 3,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: AppColors.outlineVariant.withValues(alpha: 0.2)),
                    borderRadius: BorderRadius.circular(AppRadii.button),
                  ),
                  child: PosterImage(url: movie.posterUrl),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(movie.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: AppColors.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
            if (movie.genres.isNotEmpty)
              Text(movie.genres.first,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppColors.onSurfaceVariant, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

//Vertical list of upcoming films with a release-date tag.
class _ComingSoon extends StatelessWidget {
  const _ComingSoon({required this.movies, required this.onOpen});
  final List<Movie> movies;
  final ValueChanged<Movie> onOpen;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('Coming Soon'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                for (final m in movies)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ComingSoonTile(movie: m, onTap: () => onOpen(m)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ComingSoonTile extends StatelessWidget {
  const _ComingSoonTile({required this.movie, required this.onTap});
  final Movie movie;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: GlassPanel(
        padding: const EdgeInsets.all(12),
        borderColor: AppColors.outlineVariant.withValues(alpha: 0.25),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.button),
              child: SizedBox(
                width: 76,
                height: 108,
                child: PosterImage(url: movie.posterUrl),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(movie.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 4),
                  if (movie.genres.isNotEmpty)
                    Text(movie.genres.join(', '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppColors.onSurfaceVariant,
                            fontSize: 13,
                            height: 1.3)),
                  const SizedBox(height: 8),
                  if (movie.releaseDate != null)
                    Row(
                      children: [
                        const Icon(Icons.calendar_month,
                            size: 16, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Text(
                          '${monthLabel(movie.releaseDate!).toUpperCase()} ${dayNumber(movie.releaseDate!)}',
                          style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.2),
                        ),
                      ],
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

class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const ShimmerBox(height: 48, radius: 24),
        const SizedBox(height: 24),
        const ShimmerBox(height: 24, width: 160),
        const SizedBox(height: 14),
        const ShimmerBox(height: 440, radius: 12),
        const SizedBox(height: 24),
        const ShimmerBox(height: 24, width: 140),
        const SizedBox(height: 14),
        SizedBox(
          height: 200,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: 4,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (_, _) => const ShimmerBox(width: 130, radius: 8),
          ),
        ),
      ],
    );
  }
}
