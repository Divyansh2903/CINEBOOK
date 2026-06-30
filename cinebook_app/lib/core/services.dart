import 'package:flutter/foundation.dart';

import 'api_client.dart';
import 'token_storage.dart';
import '../services/auth_service.dart';
import '../services/bookings_service.dart';
import '../services/catalog_service.dart';
import '../services/chat_service.dart';
import '../services/shows_service.dart';

//Single container for the API client and every service, provided app-wide.
class AppServices {
  AppServices._({
    required this.tokens,
    required this.api,
    required this.auth,
    required this.catalog,
    required this.shows,
    required this.bookings,
    required this.chat,
  });

  final TokenStorage tokens;
  final ApiClient api;
  final AuthService auth;
  final CatalogService catalog;
  final ShowsService shows;
  final BookingsService bookings;
  final ChatService chat;

  //Cross-screen channel: a movie detail can hand a prompt to the chat tab.
  final ValueNotifier<String?> pendingChatPrompt = ValueNotifier<String?>(null);

  //Lets a pushed route ask the shell to switch tabs (e.g. to My Bookings).
  final ValueNotifier<int?> requestedTab = ValueNotifier<int?>(null);

  //Bumped whenever the My Bookings tab is opened so the (kept-alive) list
  //re-fetches and a just-completed booking shows up immediately.
  final ValueNotifier<int> bookingsRefresh = ValueNotifier<int>(0);

  factory AppServices.build() {
    final tokens = TokenStorage();
    final api = ApiClient(tokens);
    return AppServices._(
      tokens: tokens,
      api: api,
      auth: AuthService(api, tokens),
      catalog: CatalogService(api),
      shows: ShowsService(api),
      bookings: BookingsService(api),
      chat: ChatService(api),
    );
  }
}
