import 'package:flutter/material.dart';
import 'package:moneynote/core/category_visuals.dart';
import 'package:moneynote/core/money.dart';
import 'package:moneynote/core/theme.dart';
import 'package:moneynote/data/database.dart';

/// Dòng giao dịch chuẩn dùng ở Tổng quan và Danh sách.
/// Quy ước tiền: chi và chuyển KHÔNG dấu, thu mang dấu cộng.
class TransactionTile extends StatelessWidget {
  final Transaction txn;
  final Category? category;
  final String? subtitle; // override; mặc định dùng txn.note
  final VoidCallback? onTap;
  const TransactionTile({
    super.key,
    required this.txn,
    this.category,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final money = Theme.of(context).extension<MoneyColors>()!;
    final isTransfer = txn.type == TransactionType.transfer;
    final amountColor = switch (txn.type) {
      TransactionType.income => money.income,
      TransactionType.expense => money.expense,
      TransactionType.transfer => money.transfer,
    };
    final prefix = txn.type == TransactionType.income ? '+' : '';
    final title =
        category?.name ?? (isTransfer ? 'Chuyển ví' : 'Chưa phân loại');
    final sub = subtitle ?? txn.note;

    return ListTile(
      onTap: onTap,
      leading: isTransfer
          ? Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: money.transfer.withAlpha(36),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.swap_horiz, size: 18, color: money.transfer),
            )
          : CategoryIconBox(
              iconName: category?.icon ?? 'category',
              color: category?.color ?? 0xFF9E9E9E,
            ),
      title: Text(title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
      subtitle: sub.isEmpty
          ? null
          : Text(sub,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
      trailing: Text(
        '$prefix${formatVnd(txn.amount)}',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: amountColor,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
