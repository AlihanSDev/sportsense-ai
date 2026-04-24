import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'database_models.dart' as models;
import 'database_models.dart' show hashPassword;
import 'dart:convert';

/// Supabase implementation of DatabaseServiceInterface
/// Uses custom `users` table with password hash (no Supabase Auth)
class DatabaseServiceSupabase implements models.DatabaseServiceInterface {
  final SupabaseClient _client;

  DatabaseServiceSupabase(this._client);

  // ======================= USERS =======================

  @override
  Future<models.User?> registerUser({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      // Normalize email
      final normalizedEmail = email.trim().toLowerCase();

      // Check if user exists
      final existing = await _client
          .from('users')
          .select('id')
          .eq('email', normalizedEmail)
          .maybeSingle();
      if (existing != null) {
        return null; // User already exists
      }

      // Hash password
      final passwordHash = hashPassword(password);

      // Insert new user
      final response = await _client
          .from('users')
          .insert({
            'name': name.trim(),
            'email': normalizedEmail,
            'password_hash': passwordHash,
            'created_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      return models.User(
        id: response['id'] as int,
        name: response['name'] as String,
        email: response['email'] as String,
        passwordHash: response['password_hash'] as String,
        createdAt: DateTime.parse(response['created_at']),
      );
    } catch (e) {
      print('Ошибка регистрации в Supabase: $e');
      return null;
    }
  }

  @override
  Future<models.User?> loginUser({
    required String email,
    required String password,
  }) async {
    try {
      final normalizedEmail = email.trim().toLowerCase();

      // Find user by email (case-insensitive via normalized lower-case)
      final response = await _client
          .from('users')
          .select()
          .eq('email', normalizedEmail)
          .maybeSingle();

      if (response == null) {
        return null; // User not found
      }

      final storedHash = response['password_hash'] as String;
      final inputHash = hashPassword(password);

      // Compare hashes
      if (storedHash != inputHash) {
        return null; // Invalid password
      }

      return models.User(
        id: response['id'] as int,
        name: response['name'] as String,
        email: response['email'] as String,
        passwordHash: storedHash,
        createdAt: DateTime.parse(response['created_at']),
      );
    } catch (e) {
      print('Ошибка входа в Supabase: $e');
      return null;
    }
  }

  @override
  Future<bool> userExists(String email) async {
    try {
      final normalizedEmail = email.trim().toLowerCase();
      final response = await _client
          .from('users')
          .select('id')
          .eq('email', normalizedEmail)
          .limit(1);
      return response.isNotEmpty;
    } catch (e) {
      print('Ошибка проверки пользователя: $e');
      return false;
    }
  }

  @override
  Future<models.User?> getCurrentUser() async {
    // For session-less auth, we need to store current user id in SharedPreferences or similar
    // For now, return null (user must login each session)
    // Can be extended with a simple token or session storage
    return null;
  }

  @override
  Future<models.User?> getUserById(int userId) async {
    try {
      final response = await _client
          .from('users')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (response != null) {
        return models.User(
          id: response['id'] as int,
          name: response['name'] as String,
          email: response['email'] as String,
          passwordHash: response['password_hash'] as String,
          createdAt: DateTime.parse(response['created_at']),
        );
      }
      return null;
    } catch (e) {
      print('Ошибка получения пользователя по ID: $e');
      return null;
    }
  }

  @override
  Future<void> logout() async {
    // No server-side logout needed for simple custom auth
    // Clear any local session storage here if added later
  }

  // ======================= CHATS =======================

  @override
  Future<models.ChatSessionDB?> createChat({
    required int userId,
    required String title,
  }) async {
    try {
      final response = await _client
          .from('chats')
          .insert({
            'user_id': userId,
            'title': title,
            'created_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      return models.ChatSessionDB(
        id: response['id'] as int,
        userId: userId,
        title: response['title'] as String,
        createdAt: DateTime.parse(response['created_at']),
      );
    } catch (e) {
      print('Ошибка создания чата в Supabase: $e');
      return null;
    }
  }

  @override
  Future<List<models.ChatSessionDB>> getUserChats(int userId) async {
    try {
      final response = await _client
          .from('chats')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return response.map<models.ChatSessionDB>((chat) {
        return models.ChatSessionDB(
          id: chat['id'] as int,
          userId: chat['user_id'] as int,
          title: chat['title'] as String,
          createdAt: DateTime.parse(chat['created_at']),
        );
      }).toList();
    } catch (e) {
      print('Ошибка получения чатов из Supabase: $e');
      return [];
    }
  }

  @override
  Future<void> deleteChat(int chatId) async {
    try {
      await _client.from('chats').delete().eq('id', chatId);
    } catch (e) {
      print('Ошибка удаления чата в Supabase: $e');
    }
  }

  // ======================= MESSAGES =======================

  @override
  Future<models.ChatMessageDB?> addMessage({
    required int chatId,
    required String text,
    required bool isUser,
  }) async {
    try {
      final response = await _client
          .from('messages')
          .insert({
            'chat_id': chatId,
            'text': text,
            'is_user': isUser ? 1 : 0,
            'timestamp': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      return models.ChatMessageDB(
        id: response['id'] as int,
        chatId: chatId,
        text: text,
        isUser: isUser,
        timestamp: DateTime.parse(response['timestamp']),
      );
    } catch (e) {
      print('Ошибка добавления сообщения в Supabase: $e');
      return null;
    }
  }

  @override
  Future<List<models.ChatMessageDB>> getChatMessages(int chatId) async {
    try {
      final response = await _client
          .from('messages')
          .select()
          .eq('chat_id', chatId)
          .order('timestamp', ascending: true);

      return response.map<models.ChatMessageDB>((msg) {
        return models.ChatMessageDB(
          id: msg['id'] as int,
          chatId: msg['chat_id'] as int,
          text: msg['text'] as String,
          isUser: msg['is_user'] == 1,
          timestamp: DateTime.parse(msg['timestamp']),
        );
      }).toList();
    } catch (e) {
      print('Ошибка получения сообщений из Supabase: $e');
      return [];
    }
  }

  @override
  Future<void> clearChatMessages(int chatId) async {
    try {
      await _client.from('messages').delete().eq('chat_id', chatId);
    } catch (e) {
      print('Ошибка очистки сообщений в Supabase: $e');
    }
  }

  @override
  Future<bool> updateChatTitle({
    required int chatId,
    required String title,
  }) async {
    try {
      await _client.from('chats').update({'title': title}).eq('id', chatId);
      return true;
    } catch (e) {
      print('Ошибка обновления названия чата в Supabase: $e');
      return false;
    }
  }

  // ======================= SAVED ITEMS =======================

  @override
  Future<models.SavedItem?> saveItem({
    required int userId,
    required String title,
    required String subtitle,
    required String type,
    String? metadata,
  }) async {
    try {
      final response = await _client
          .from('saved_items')
          .insert({
            'user_id': userId,
            'title': title,
            'subtitle': subtitle,
            'type': type,
            'metadata': metadata,
            'created_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      return models.SavedItem(
        id: response['id'] as int,
        userId: userId,
        title: title,
        subtitle: subtitle,
        type: type,
        metadata: metadata,
        createdAt: DateTime.parse(response['created_at']),
      );
    } catch (e) {
      print('Ошибка сохранения элемента в Supabase: $e');
      return null;
    }
  }

  @override
  Future<List<models.SavedItem>> getUserSavedItems(int userId) async {
    try {
      final response = await _client
          .from('saved_items')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return response.map<models.SavedItem>((item) {
        return models.SavedItem(
          id: item['id'] as int,
          userId: item['user_id'] as int,
          title: item['title'] as String,
          subtitle: item['subtitle'] as String,
          type: item['type'] as String,
          metadata: item['metadata'] as String?,
          createdAt: DateTime.parse(item['created_at']),
        );
      }).toList();
    } catch (e) {
      print('Ошибка получения сохраненных элементов из Supabase: $e');
      return [];
    }
  }

  @override
  Future<void> deleteSavedItem(int itemId) async {
    try {
      await _client.from('saved_items').delete().eq('id', itemId);
    } catch (e) {
      print('Ошибка удаления элемента в Supabase: $e');
    }
  }

  @override
  Future<void> close() async {
    // Nothing to close for Supabase client
  }
}
