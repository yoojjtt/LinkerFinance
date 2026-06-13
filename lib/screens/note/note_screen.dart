import 'package:flutter/material.dart';

import 'calendar/calendar_tab.dart';
import 'journal/journal_tab.dart';
import 'psych/psych_tab.dart';
import 'strategy/strategy_tab.dart';

class NoteScreen extends StatelessWidget {
  const NoteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          Container(
            color: Colors.white,
            child: const TabBar(
              labelColor: Color(0xFF1B2E5C),
              unselectedLabelColor: Color(0xFF9E9E9E),
              labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              unselectedLabelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              indicatorColor: Color(0xFF1B2E5C),
              indicatorWeight: 2.5,
              tabs: [
                Tab(text: '시장일지'),
                Tab(text: '심리'),
                Tab(text: '매매기법'),
                Tab(text: '일정관리'),
              ],
            ),
          ),
          const Expanded(
            child: TabBarView(
              children: [
                JournalTab(),
                PsychTab(),
                StrategyTab(),
                CalendarTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
