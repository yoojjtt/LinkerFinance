import 'package:flutter/material.dart';

import '../../models/macro_asset_model.dart';
import '../../utils/macro_utils.dart';

class CrossSignalSection extends StatelessWidget {
  final List<CrossSignal> signals;

  const CrossSignalSection({super.key, required this.signals});

  @override
  Widget build(BuildContext context) {
    if (signals.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.insights, size: 16, color: Color(0xFF1B2E5C)),
              SizedBox(width: 6),
              Text(
                '크로스 시그널',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1B2E5C)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...signals.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(getSignalIcon(s.type), size: 16, color: getSignalColor(s.type)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        s.message,
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.4),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
