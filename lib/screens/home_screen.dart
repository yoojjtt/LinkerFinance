import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/fcm_service.dart';
import 'home/market_home_screen.dart';
import 'more/more_screen.dart';
import 'my_info/my_info_screen.dart';
import 'note/note_screen.dart';
import 'notification_list_screen.dart';
import 'stock/stock_search_screen.dart';
import 'watchlist/watchlist_screen.dart';

// Design Ref: §6 — HomeScreen with BottomNavigationBar (홈/관심종목/노트/더보기/내정보 5탭)
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final _pages = const [
    MarketHomeScreen(),
    WatchlistScreen(),
    NoteScreen(),
    MoreScreen(),
    MyInfoScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Design Ref: §4.3 — 종료 상태 푸시 탭으로 보류된 상세를 홈 마운트 후 진입
    // Plan SC: SC-06
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FcmService().flushPendingDetail();
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: const Color(0xFF1B2E5C),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Center(
                child: Text(
                  'L',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'LINKER.',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1B2E5C),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Color(0xFF1B2E5C)),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const StockSearchScreen()),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Center(
              child: Text(
                '${user?.userName ?? ''} 님',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF3A3A3A),
                ),
              ),
            ),
          ),
          ValueListenableBuilder<int>(
            valueListenable: FcmService().unreadCount,
            builder: (context, count, _) {
              return IconButton(
                icon: Badge(
                  isLabelVisible: count > 0,
                  label: Text(
                    count > 99 ? '99+' : '$count',
                    style: const TextStyle(fontSize: 10),
                  ),
                  child: const Icon(
                    Icons.notifications_outlined,
                    color: Color(0xFF1B2E5C),
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const NotificationListScreen(),
                    ),
                  );
                },
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        selectedItemColor: const Color(0xFF1B2E5C),
        unselectedItemColor: Colors.grey.shade400,
        backgroundColor: Colors.white,
        elevation: 8,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: '홈',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.star_outline),
            activeIcon: Icon(Icons.star),
            label: '관심종목',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.edit_note_outlined),
            activeIcon: Icon(Icons.edit_note),
            label: '노트',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.apps_outlined),
            activeIcon: Icon(Icons.apps),
            label: '더보기',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: '내정보',
          ),
        ],
      ),
    );
  }
}

