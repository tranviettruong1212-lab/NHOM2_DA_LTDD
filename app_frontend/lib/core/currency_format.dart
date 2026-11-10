class CurrencyFormat {
  CurrencyFormat._();

  /// Định dạng số tiền theo chuẩn Việt Nam: `1.500.000 ₫`, `-250.000 ₫`
  static String format(num amount, {String symbol = '₫'}) {
    final isNegative = amount < 0;
    final absAmount = amount.abs();
    final integerPart = absAmount.truncate();

    final digits = integerPart.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      buffer.write(digits[i]);
      final remaining = digits.length - i - 1;
      if (remaining > 0 && remaining % 3 == 0) {
        buffer.write('.');
      }
    }

    final formatted = buffer.toString();
    return '${isNegative ? '-' : ''}$formatted $symbol';
  }

  /// Định dạng ngắn gọn cho đồ thị hoặc nhãn nhỏ: `1.5M`, `200K`
  static String compact(num amount) {
    final absAmount = amount.abs();
    final isNegative = amount < 0;
    final prefix = isNegative ? '-' : '';

    if (absAmount >= 1000000000) {
      return '$prefix${(absAmount / 1000000000).toStringAsFixed(1)}Tỷ';
    }
    if (absAmount >= 1000000) {
      final value = (absAmount / 1000000);
      final formatted = value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
      return '$prefix${formatted}Tr';
    }
    if (absAmount >= 1000) {
      final value = (absAmount / 1000);
      final formatted = value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(0);
      return '$prefix${formatted}K';
    }
    return '$prefix${absAmount.toStringAsFixed(0)}';
  }
}

