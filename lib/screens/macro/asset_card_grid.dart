import 'package:flutter/material.dart';

import '../../models/macro_asset_model.dart';
import '../../utils/macro_utils.dart';

class AssetCardGrid extends StatelessWidget {
  final List<MacroAsset> assets;
  final String? selectedSymbol;
  final ValueChanged<String> onSelect;

  const AssetCardGrid({
    super.key,
    required this.assets,
    this.selectedSymbol,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.6,
        ),
        itemCount: assets.length,
        itemBuilder: (context, index) => _buildCard(assets[index]),
      ),
    );
  }

  Widget _buildCard(MacroAsset asset) {
    final danger = getAssetDanger(asset);
    final isSelected = selectedSymbol == asset.symbol;

    return GestureDetector(
      onTap: () => onSelect(asset.symbol),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1B2E5C).withValues(alpha: 0.05) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF1B2E5C) : Colors.grey.shade200,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    asset.name,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF3A3A3A)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: getDangerColor(danger).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    danger,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: getDangerColor(danger)),
                  ),
                ),
              ],
            ),
            Text(
              formatPrice(asset.price, asset.symbol),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1B2E5C)),
            ),
            Text(
              formatChange(asset.change, asset.changePercent),
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: getChangeColor(asset.changePercent)),
            ),
          ],
        ),
      ),
    );
  }
}
