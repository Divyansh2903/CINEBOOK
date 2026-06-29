import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services.dart';
import '../../core/theme.dart';
import '../../models/movie.dart';
import '../../widgets/common.dart';
import '../../widgets/movie_card.dart';
import '../../widgets/poster.dart';
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
    return _HomeData(
      trending: results[0],
      nowPlaying: results[1],
      upcoming: results[2],
    );
  }

  Future<void> _refresh() async {
    final data = await _load();
    if (mounted) setState(() => _future = Future.value(data));
  }

  void _openMovie(Movie m) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => MovieDetailScreen(movieId: m.id, preview: m)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
          final featured = data.trending.isNotEmpty
              ? data.trending.first
              : (data.nowPlaying.isNotEmpty ? data.nowPlaying.first : null);
          return RefreshIndicator(
            color: AppColors.primary,
            backgroundColor: AppColors.surfaceContainerHigh,
            onRefresh: _refresh,
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: featured == null
                      ? const SizedBox(height: 80)
                      : _Hero(movie: featured, onBook: () => _openMovie(featured)),
                ),
                SliverToBoxAdapter(
                  child: _SearchTeaser(
                    onTap: () => MainShell.of(context)?.goToTab(1),
                  ),
                ),
                _railSliver('Trending Now', data.trending),
                _railSliver('Now Playing', data.nowPlaying),
                _railSliver('Coming Soon', data.upcoming),
                const SliverToBoxAdapter(child: SizedBox(height: 90)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _railSliver(String title, List<Movie> movies) {
    if (movies.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(title),
            SizedBox(
              height: 225,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: movies.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (_, i) =>
                    MovieCard(movie: movies[i], onTap: () => _openMovie(movies[i])),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeData {
  _HomeData({required this.trending, required this.nowPlaying, required this.upcoming});
  final List<Movie> trending;
  final List<Movie> nowPlaying;
  final List<Movie> upcoming;
}

//Wide-bleed backdrop with the featured film's headline + actions.
class _Hero extends StatelessWidget {
  const _Hero({required this.movie, required this.onBook});
  final Movie movie;
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 520,
      child: Stack(
        fit: StackFit.expand,
        children: [
          PosterImage(url: movie.backdropUrl ?? movie.posterUrl),
          DecoratedBox(decoration: topScrim()),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.location_on, color: AppColors.primary, size: 18),
                        SizedBox(width: 4),
                        Text('Bengaluru',
                            style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600)),
                        Icon(Icons.expand_more, color: AppColors.primary, size: 18),
                      ],
                    ),
                    const Icon(Icons.notifications_none, color: AppColors.primary),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    if (movie.genres.isNotEmpty)
                      MetaChip(movie.genres.first, highlighted: true),
                    const SizedBox(width: 8),
                    if (movie.ageRating != null) MetaChip(movie.ageRating!),
                  ],
                ),
                const SizedBox(height: 12),
                Text(movie.title, style: Theme.of(context).textTheme.displayLarge),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: onBook,
                        icon: const Icon(Icons.confirmation_number, size: 18),
                        label: const Text('Book Now'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchTeaser extends StatelessWidget {
  const _SearchTeaser({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      child: GestureDetector(
        onTap: onTap,
        child: GlassPanel(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: const [
              Icon(Icons.search, color: AppColors.onSurfaceVariant),
              SizedBox(width: 12),
              Text('Search movies, cinemas, genres…',
                  style: TextStyle(color: AppColors.onSurfaceVariant)),
            ],
          ),
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
        const ShimmerBox(height: 360, radius: 12),
        const SizedBox(height: 24),
        const ShimmerBox(height: 24, width: 160),
        const SizedBox(height: 12),
        SizedBox(
          height: 210,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: 4,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (_, _) => const ShimmerBox(width: 140, radius: 12),
          ),
        ),
      ],
    );
  }
}
