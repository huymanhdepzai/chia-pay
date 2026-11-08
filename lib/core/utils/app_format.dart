import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Định dạng số tiền (lưu dạng số nguyên) kèm đơn vị tiền tệ của nhóm.
String formatMoney(int amount, String currency) {
  return NumberFormat.currency(locale: 'vi_VN', symbol: currency, decimalDigits: 0).format(amount);
}

/// Định dạng số không kèm đơn vị, dùng cho ô nhập và CSV.
String formatNumber(int amount) => NumberFormat.decimalPattern('vi_VN').format(amount);

/// Đọc số tiền người dùng nhập, bỏ dấu phân cách hàng nghìn.
int? parseAmount(String input) {
  final digits = input.replaceAll(RegExp(r'[.,\s]'), '');
  if (digits.isEmpty) return null;
  return int.tryParse(digits);
}

String formatDate(DateTime date) => DateFormat('dd/MM/yyyy').format(date);

String formatShortDate(DateTime date) => DateFormat('dd/MM').format(date);

/// Danh mục khoản chi và icon tương ứng.
const Map<String, IconData> expenseCategories = {
  'Ăn uống': Icons.restaurant,
  'Di chuyển': Icons.directions_car,
  'Chỗ ở': Icons.hotel,
  'Vui chơi': Icons.local_play,
  'Mua sắm': Icons.shopping_bag,
  'Hóa đơn': Icons.receipt,
  'Khác': Icons.category,
};

IconData categoryIcon(String category) => expenseCategories[category] ?? Icons.category;

/// Màu theo phong cách tài chính: xanh cho khoản cần nhận, đỏ/cam cho khoản cần trả.
const Color positiveColor = Color(0xFF16A34A);
const Color negativeColor = Color(0xFFEA580C);

Color balanceColor(int balance, {Color neutral = Colors.grey}) {
  if (balance > 0) return positiveColor;
  if (balance < 0) return negativeColor;
  return neutral;
}

/// Màu nền/chữ dùng chung, tự đổi theo giao diện sáng/tối.
extension AppColors on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  Color get cardColor => isDark ? const Color(0xFF1C2230) : Colors.white;

  Color get fieldColor => isDark ? const Color(0xFF252C3B) : Colors.grey[50]!;

  Color get borderColor => isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey[100]!;

  Color get textPrimary => Theme.of(this).colorScheme.onSurface;

  Color get textSecondary => isDark ? Colors.grey[400]! : Colors.grey[600]!;
}
