/// Utility functions for chat operations
class ChatUtils {
  /// Generates a consistent chat ID for any two users.
  /// The ID is always the same regardless of parameter order.
  static String generateChatId(String uid1, String uid2) {
    // Always sort the IDs to ensure consistency
    final ids = [uid1, uid2]..sort();
    return 'chat_${ids[0]}_${ids[1]}';
  }

  /// Validates if a chat ID is in the correct format
  static bool isValidChatId(String chatId) {
    final parts = chatId.split('_');
    return parts.length == 3 && 
           parts[0] == 'chat' &&
           parts[1].isNotEmpty &&
           parts[2].isNotEmpty;
  }

  /// Extracts user IDs from a chat ID
  static List<String> getUserIdsFromChatId(String chatId) {
    if (!isValidChatId(chatId)) return [];
    final parts = chatId.split('_');
    return [parts[1], parts[2]];
  }
}
