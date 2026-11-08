abstract class SettingsRepository {
  Future<String?> get(String key);
  Future<void> set(String key, String value);
  Future<void> remove(String key);
}

abstract class BackupRepository {
  /// Xuất toàn bộ dữ liệu ra chuỗi JSON.
  Future<String> exportJson();

  /// Thay thế toàn bộ dữ liệu bằng nội dung bản sao lưu. Ném [FormatException] nếu file không hợp lệ.
  Future<void> importJson(String json);
}
