import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services.dart';
import '../../core/theme.dart';
import '../../services/catalog_service.dart';
import '../../widgets/common.dart';

//Bottom sheet for the browse filters; returns the chosen MovieFilters.
class FilterSheet extends StatefulWidget {
  const FilterSheet({super.key, required this.initial});
  final MovieFilters initial;
  @override
  State<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
  String? _genre;
  String? _language;
  String? _format;
  String? _ageRating;
  String? _screenType;

  List<String> _genres = [];
  List<String> _languages = [];

  @override
  void initState() {
    super.initState();
    _genre = widget.initial.genre;
    _language = widget.initial.language;
    _format = widget.initial.format;
    _ageRating = widget.initial.ageRating;
    _screenType = widget.initial.screenType;
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    final catalog = context.read<AppServices>().catalog;
    try {
      final genres = await catalog.genres();
      final languages = await catalog.languages();
      if (!mounted) return;
      setState(() {
        _genres = genres.map((g) => g.name).toList();
        _languages = languages;
      });
    } catch (_) {}
  }

  void _apply() {
    Navigator.of(context).pop(MovieFilters(
      genre: _genre,
      language: _language,
      format: _format,
      ageRating: _ageRating,
      screenType: _screenType,
    ));
  }

  void _clear() {
    setState(() {
      _genre = null;
      _language = null;
      _format = null;
      _ageRating = null;
      _screenType = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, controller) => GlassPanel(
        radius: 20,
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Row(
                children: [
                  Text('Filters', style: Theme.of(context).textTheme.titleLarge),
                  const Spacer(),
                  TextButton(
                    onPressed: _clear,
                    child: const Text('Clear all',
                        style: TextStyle(color: AppColors.onSurfaceVariant)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                children: [
                  if (_genres.isNotEmpty)
                    _group('Genre', _genres, _genre,
                        (v) => setState(() => _genre = v)),
                  if (_languages.isNotEmpty)
                    _group('Language', _languages, _language,
                        (v) => setState(() => _language = v)),
                  _group('Format', const ['TWO_D', 'THREE_D'], _format,
                      (v) => setState(() => _format = v),
                      labels: const {'TWO_D': '2D', 'THREE_D': '3D'}),
                  _group('Age Rating', const ['U', 'UA', 'A'], _ageRating,
                      (v) => setState(() => _ageRating = v)),
                  _group(
                    'Screen Type',
                    const ['STANDARD', 'IMAX', 'FOUR_DX', 'DOLBY_ATMOS'],
                    _screenType,
                    (v) => setState(() => _screenType = v),
                    labels: const {
                      'STANDARD': 'Standard',
                      'IMAX': 'IMAX',
                      'FOUR_DX': '4DX',
                      'DOLBY_ATMOS': 'Dolby Atmos',
                    },
                  ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _apply,
                    child: const Text('Show Results'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _group(
    String title,
    List<String> options,
    String? selected,
    ValueChanged<String?> onPick, {
    Map<String, String>? labels,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(title,
            style: const TextStyle(
                color: AppColors.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                fontSize: 13,
                letterSpacing: 0.5)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final opt in options)
              _Chip(
                label: labels?[opt] ?? opt,
                active: selected == opt,
                onTap: () => onPick(selected == opt ? null : opt),
              ),
          ],
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: active
              ? AppColors.primary.withValues(alpha: 0.15)
              : AppColors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: Border.all(
            color: active ? AppColors.primary : AppColors.outlineVariant,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? AppColors.primary : AppColors.onSurface,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
