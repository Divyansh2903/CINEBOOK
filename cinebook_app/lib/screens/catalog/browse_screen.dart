import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services.dart';
import '../../core/theme.dart';
import '../../models/movie.dart';
import '../../services/catalog_service.dart';
import '../../widgets/common.dart';
import '../../widgets/movie_card.dart';
import '../movie_detail/movie_detail_screen.dart';
import 'filter_sheet.dart';

class BrowseScreen extends StatefulWidget {
  const BrowseScreen({super.key});
  @override
  State<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends State<BrowseScreen> {
  final _search = TextEditingController();
  MovieFilters _filters = const MovieFilters();
  late Future<List<Movie>> _future;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<List<Movie>> _load() =>
      context.read<AppServices>().catalog.movies(filters: _filters);

  void _reload() => setState(() => _future = _load());

  int get _activeFilterCount {
    var n = 0;
    if (_filters.genre != null) n++;
    if (_filters.language != null) n++;
    if (_filters.format != null) n++;
    if (_filters.ageRating != null) n++;
    if (_filters.screenType != null) n++;
    return n;
  }

  Future<void> _openFilters() async {
    final result = await showModalBottomSheet<MovieFilters>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => FilterSheet(initial: _filters),
    );
    if (result != null) {
      setState(() => _filters = result);
      _reload();
    }
  }

  List<Movie> _applyQuery(List<Movie> movies) {
    if (_query.isEmpty) return movies;
    final q = _query.toLowerCase();
    return movies
        .where((m) =>
            m.title.toLowerCase().contains(q) ||
            m.genres.any((g) => g.toLowerCase().contains(q)))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _search,
                      onChanged: (v) => setState(() => _query = v.trim()),
                      style: const TextStyle(color: AppColors.onSurface),
                      decoration: InputDecoration(
                        hintText: 'Search movies, genres…',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () {
                                  _search.clear();
                                  setState(() => _query = '');
                                },
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _FilterButton(count: _activeFilterCount, onTap: _openFilters),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<List<Movie>>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const _GridSkeleton();
                  }
                  if (snap.hasError) {
                    return StateMessage(
                      icon: Icons.cloud_off_rounded,
                      title: 'Could not load movies',
                      subtitle: '${snap.error}',
                      onRetry: _reload,
                    );
                  }
                  final movies = _applyQuery(snap.data!);
                  if (movies.isEmpty) {
                    return const StateMessage(
                      icon: Icons.movie_filter_outlined,
                      title: 'No movies found',
                      subtitle: 'Try adjusting your search or filters.',
                    );
                  }
                  return GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 2 / 3,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: movies.length,
                    itemBuilder: (_, i) => MovieCard(
                      movie: movies[i],
                      width: double.infinity,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => MovieDetailScreen(
                            movieId: movies[i].id,
                            preview: movies[i],
                          ),
                        ),
                      ),
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

class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.button),
      child: Container(
        height: 52,
        width: 52,
        decoration: BoxDecoration(
          color: count > 0 ? AppColors.primary : AppColors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(AppRadii.button),
        ),
        child: Icon(
          Icons.tune,
          color: count > 0 ? AppColors.onPrimary : AppColors.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _GridSkeleton extends StatelessWidget {
  const _GridSkeleton();
  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2 / 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: 6,
      itemBuilder: (_, _) => const ShimmerBox(radius: 12),
    );
  }
}
