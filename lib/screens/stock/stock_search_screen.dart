import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/stock_model.dart';
import '../../services/stock_service.dart';
import 'stock_detail_screen.dart';

class StockSearchScreen extends StatefulWidget {
  const StockSearchScreen({super.key});

  @override
  State<StockSearchScreen> createState() => _StockSearchScreenState();
}

class _StockSearchScreenState extends State<StockSearchScreen> {
  final _controller = TextEditingController();
  List<StockSearchResult> _results = [];
  bool _isLoading = false;
  Timer? _debounce;

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _search(query);
    });
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }

    setState(() => _isLoading = true);
    final results = await StockService.search(query);
    if (mounted) {
      setState(() {
        _results = results;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1B2E5C)),
          onPressed: () => Navigator.pop(context),
        ),
        title: TextField(
          controller: _controller,
          autofocus: true,
          onChanged: _onSearchChanged,
          decoration: InputDecoration(
            hintText: '종목명 또는 코드 검색',
            hintStyle: TextStyle(fontSize: 15, color: Colors.grey.shade400),
            border: InputBorder.none,
            suffixIcon: _controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      _controller.clear();
                      setState(() => _results = []);
                    },
                  )
                : null,
          ),
          style: const TextStyle(fontSize: 15, color: Color(0xFF1B2E5C)),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : _results.isEmpty
              ? _buildEmpty()
              : _buildResultList(),
    );
  }

  Widget _buildEmpty() {
    if (_controller.text.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('종목명 또는 코드를 입력하세요',
                style: TextStyle(fontSize: 15, color: Colors.grey.shade400)),
          ],
        ),
      );
    }
    return Center(
      child: Text('검색 결과가 없습니다',
          style: TextStyle(fontSize: 15, color: Colors.grey.shade400)),
    );
  }

  Widget _buildResultList() {
    final priceFormat = NumberFormat('#,##0');

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _results.length,
      separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade200),
      itemBuilder: (context, index) {
        final stock = _results[index];
        return ListTile(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => StockDetailScreen(
                  stockCode: stock.code,
                  stockName: stock.name,
                  currentPrice: stock.parsedPrice.toDouble(),
                ),
              ),
            );
          },
          title: Row(
            children: [
              Text(stock.name,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1B2E5C))),
              const SizedBox(width: 8),
              Text(stock.code,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
            ],
          ),
          subtitle: Row(
            children: [
              if (stock.marketName.isNotEmpty)
                _tag(stock.marketName == '거래소' ? 'KOSPI' : 'KOSDAQ'),
              if (stock.upName != null && stock.upName!.isNotEmpty) ...[
                const SizedBox(width: 4),
                _tag(stock.upName!),
              ],
            ],
          ),
          trailing: stock.parsedPrice > 0
              ? Text('${priceFormat.format(stock.parsedPrice)}원',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF3A3A3A)))
              : null,
        );
      },
    );
  }

  Widget _tag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F7),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
    );
  }
}
