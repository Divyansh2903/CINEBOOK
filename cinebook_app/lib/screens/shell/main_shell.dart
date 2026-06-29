import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services.dart';
import '../../core/theme.dart';
import '../bookings/bookings_screen.dart';
import '../catalog/browse_screen.dart';
import '../chat/chat_screen.dart';
import '../home/home_screen.dart';
import '../profile/profile_screen.dart';

//The authenticated home: five tabs behind a frosted bottom bar.
class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => MainShellState();

  //Lets descendant screens jump tabs (e.g. "open Chat" from a movie detail).
  static MainShellState? of(BuildContext context) =>
      context.findAncestorStateOfType<MainShellState>();
}

class MainShellState extends State<MainShell> {
  int _index = 0;
  ValueNotifier<String?>? _chatPrompt;
  ValueNotifier<int?>? _requestedTab;

  void goToTab(int index) => setState(() => _index = index);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final services = context.read<AppServices>();
    final prompt = services.pendingChatPrompt;
    if (_chatPrompt != prompt) {
      _chatPrompt?.removeListener(_onChatPrompt);
      _chatPrompt = prompt..addListener(_onChatPrompt);
    }
    final tab = services.requestedTab;
    if (_requestedTab != tab) {
      _requestedTab?.removeListener(_onRequestedTab);
      _requestedTab = tab..addListener(_onRequestedTab);
    }
  }

  //A queued prompt (e.g. "Ask AI" from a movie) jumps to the Chat tab.
  void _onChatPrompt() {
    if (_chatPrompt?.value != null && _index != 3) goToTab(3);
  }

  void _onRequestedTab() {
    final target = _requestedTab?.value;
    if (target != null) {
      _requestedTab!.value = null;
      goToTab(target);
    }
  }

  @override
  void dispose() {
    _chatPrompt?.removeListener(_onChatPrompt);
    _requestedTab?.removeListener(_onRequestedTab);
    super.dispose();
  }

  static const _tabs = [
    _TabSpec(Icons.home_rounded, Icons.home_outlined, 'Home'),
    _TabSpec(Icons.search_rounded, Icons.search, 'Search'),
    _TabSpec(Icons.confirmation_number, Icons.confirmation_number_outlined, 'Bookings'),
    _TabSpec(Icons.chat_bubble, Icons.chat_bubble_outline, 'Chat'),
    _TabSpec(Icons.person, Icons.person_outline, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _index,
        children: const [
          HomeScreen(),
          BrowseScreen(),
          BookingsScreen(),
          ChatScreen(),
          ProfileScreen(),
        ],
      ),
      bottomNavigationBar: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest.withValues(alpha: 0.9),
              border: const Border(
                top: BorderSide(color: Color(0x334D4635)),
              ),
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: 64,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    for (var i = 0; i < _tabs.length; i++)
                      _TabButton(
                        spec: _tabs[i],
                        active: i == _index,
                        onTap: () => goToTab(i),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabSpec {
  const _TabSpec(this.active, this.inactive, this.label);
  final IconData active;
  final IconData inactive;
  final String label;
}

class _TabButton extends StatelessWidget {
  const _TabButton({required this.spec, required this.active, required this.onTap});
  final _TabSpec spec;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.primary : AppColors.secondaryFixedDim;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(active ? spec.active : spec.inactive, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              spec.label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
