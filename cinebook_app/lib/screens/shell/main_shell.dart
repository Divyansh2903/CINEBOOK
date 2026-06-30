import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services.dart';
import '../bookings/bookings_screen.dart';
import '../catalog/browse_screen.dart';
import '../chat/chat_screen.dart';
import '../home/home_screen.dart';
import '../profile/profile_screen.dart';
import 'bottom_nav_bar.dart';

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
      bottomNavigationBar: BottomNavBar(currentIndex: _index, onTap: goToTab),
    );
  }
}
