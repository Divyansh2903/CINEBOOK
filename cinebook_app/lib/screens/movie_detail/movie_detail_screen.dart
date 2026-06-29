import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services.dart';
import '../../core/theme.dart';
import '../../models/enums.dart';
import '../../models/movie.dart';
import '../../widgets/common.dart';
import '../../widgets/movie_card.dart';
import '../../widgets/poster.dart';
import '../booking/show_selection_screen.dart';

class MovieDetailScreen extends StatefulWidget {
  const MovieDetailScreen({super.key, required this.movieId, this.preview});
  final String movieId;
  //An optional list-shape movie shown instantly while detail loads.
  final Movie? preview;

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  late Future<Movie> _future;
  List<Movie> _similar = [];

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Movie> _load() async {
    final catalog = context.read<AppServices>().catalog;
    final movie = await catalog.movie(widget.movieId);
    catalog.similar(widget.movieId).then((s) {
      if (mounted) setState(() => _similar = s);
    }).catchError((_) {});
    return movie;
  }

  void _book(Movie movie) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ShowSelectionScreen(movie: movie)),
    );
  }

  void _askAi(Movie movie) {
    //Hand a prompt to the chat tab, then reveal the shell beneath this route.
    context.read<AppServices>().pendingChatPrompt.value =
        'Tell me about "${movie.title}" — is it worth watching?';
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<Movie>(
        future: _future,
        initialData: widget.preview,
        builder: (context, snap) {
          final movie = snap.data;
          if (movie == null) {
            if (snap.hasError) {
              return StateMessage(
                icon: Icons.error_outline,
                title: 'Movie unavailable',
                subtitle: '${snap.error}',
                onRetry: () => setState(() => _future = _load()),
              );
            }
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }
          final loadingDetail = snap.connectionState == ConnectionState.waiting;
          return _Content(
            movie: movie,
            similar: _similar,
            loadingDetail: loadingDetail,
            onBook: () => _book(movie),
            onAskAi: () => _askAi(movie),
            onOpenSimilar: (m) => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => MovieDetailScreen(movieId: m.id, preview: m),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({
    required this.movie,
    required this.similar,
    required this.loadingDetail,
    required this.onBook,
    required this.onAskAi,
    required this.onOpenSimilar,
  });

  final Movie movie;
  final List<Movie> similar;
  final bool loadingDetail;
  final VoidCallback onBook;
  final VoidCallback onAskAi;
  final ValueChanged<Movie> onOpenSimilar;

  double? get _avgRating {
    if (movie.reviews.isEmpty) return null;
    final sum = movie.reviews.fold<double>(0, (a, r) => a + r.rating);
    return sum / movie.reviews.length;
  }

  @override
  Widget build(BuildContext context) {
    final meta = <String>[
      if (movie.runtimeMin != null) movie.runtimeLabel,
      if (movie.genres.isNotEmpty) movie.genres.join(', '),
    ];
    return Stack(
      children: [
        CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _Hero(movie: movie)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(movie.title,
                        style: Theme.of(context).textTheme.displayLarge
                            ?.copyWith(color: AppColors.primary)),
                    const SizedBox(height: 8),
                    if (meta.isNotEmpty)
                      Text(meta.join('  •  '),
                          style: const TextStyle(
                              color: AppColors.onSurfaceVariant, fontSize: 13)),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (movie.ageRating != null)
                          MetaChip('Age ${movie.ageRating}'),
                        if (movie.format != null)
                          MetaChip(formatLabel(movie.format)),
                        if (movie.language != null) MetaChip(movie.language!),
                        if (_avgRating != null)
                          MetaChip(_avgRating!.toStringAsFixed(1),
                              icon: Icons.star_rounded, highlighted: true),
                      ],
                    ),
                    const SizedBox(height: 24),
                    if (movie.description != null) ...[
                      Text('Synopsis',
                          style: Theme.of(context).textTheme.headlineMedium),
                      const SizedBox(height: 12),
                      Text(movie.description!,
                          style: const TextStyle(
                              color: AppColors.onSurfaceVariant,
                              height: 1.5,
                              fontSize: 15)),
                      const SizedBox(height: 24),
                    ] else if (loadingDetail) ...[
                      const ShimmerBox(height: 80, radius: 8),
                      const SizedBox(height: 24),
                    ],
                  ],
                ),
              ),
            ),
            if (movie.cast.isNotEmpty) _castSliver(context),
            if (movie.reviews.isNotEmpty) _reviewsSliver(context),
            if (similar.isNotEmpty) _similarSliver(context),
            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
        _BackButton(),
        _BottomActions(
          movieTitle: movie.title,
          onBook: onBook,
          onAskAi: onAskAi,
        ),
      ],
    );
  }

  Widget _castSliver(BuildContext context) => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text('Cast',
                    style: Theme.of(context).textTheme.headlineMedium),
              ),
              SizedBox(
                height: 120,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: movie.cast.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 16),
                  itemBuilder: (_, i) {
                    final c = movie.cast[i];
                    return SizedBox(
                      width: 80,
                      child: Column(
                        children: [
                          ClipOval(
                            child: SizedBox(
                              width: 64,
                              height: 64,
                              child: PosterImage(
                                  url: c.photoUrl,
                                  icon: Icons.person),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(c.name,
                              maxLines: 2,
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 11, color: AppColors.onSurface)),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );

  Widget _reviewsSliver(BuildContext context) => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Reviews',
                        style: Theme.of(context).textTheme.headlineMedium),
                    const Spacer(),
                    if (_avgRating != null) ...[
                      Text(_avgRating!.toStringAsFixed(1),
                          style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 22,
                              fontWeight: FontWeight.w700)),
                      const Text(' / 5',
                          style: TextStyle(color: AppColors.onSurfaceVariant)),
                    ],
                  ],
                ),
                const Divider(height: 24),
                for (final r in movie.reviews) ...[
                  Text('"${r.text}"',
                      style: const TextStyle(
                          color: AppColors.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                          height: 1.4)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text('— ${r.author}',
                          style: const TextStyle(
                              color: AppColors.onSurface, fontSize: 12)),
                      const Spacer(),
                      RatingBadge(r.rating, size: 12),
                    ],
                  ),
                  const SizedBox(height: 14),
                ],
              ],
            ),
          ),
        ),
      );

  Widget _similarSliver(BuildContext context) => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader('More Like This'),
              SizedBox(
                height: 210,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: similar.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (_, i) => MovieCard(
                    movie: similar[i],
                    width: 130,
                    onTap: () => onOpenSimilar(similar[i]),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

class _Hero extends StatelessWidget {
  const _Hero({required this.movie});
  final Movie movie;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 380,
      child: Stack(
        fit: StackFit.expand,
        children: [
          PosterImage(url: movie.backdropUrl ?? movie.posterUrl),
          DecoratedBox(decoration: topScrim()),
          if (movie.trailerUrl != null)
            Center(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xCC161618),
                  shape: BoxShape.circle,
                  boxShadow: AppShadows.goldGlow,
                ),
                child: const Icon(Icons.play_arrow_rounded,
                    color: AppColors.primary, size: 36),
              ),
            ),
        ],
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: CircleAvatar(
          backgroundColor: const Color(0xCC161618),
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.onSurface),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
      ),
    );
  }
}

class _BottomActions extends StatelessWidget {
  const _BottomActions({
    required this.movieTitle,
    required this.onBook,
    required this.onAskAi,
  });
  final String movieTitle;
  final VoidCallback onBook;
  final VoidCallback onAskAi;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: GlassPanel(
        radius: 0,
        padding: EdgeInsets.zero,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: onBook,
                    child: const Text('Book Tickets'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: OutlinedButton.icon(
                    onPressed: onAskAi,
                    icon: const Icon(Icons.smart_toy_outlined, size: 18),
                    label: const Text('Ask AI'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
