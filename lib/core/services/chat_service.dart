// ─── Chat Service ─────────────────────────────────────────────────────────────
// One conversation per order, between its customer and its tailor. Shared by
// the customer and tailor apps. Throws [ApiException] on failure.

import '../api/api_client.dart';
import '../models/app_models.dart';

class ChatService {
  static final ChatService _instance = ChatService._();
  factory ChatService() => _instance;
  ChatService._();

  final ApiClient _api = ApiClient();

  // GET /api/conversations
  Future<List<ConversationModel>> getConversations() async =>
      listOf(await _api.get('/conversations'), ConversationModel.fromJson);

  // GET /api/orders/:id/messages
  Future<List<MessageModel>> getMessages(String orderId) async =>
      listOf(await _api.get('/orders/$orderId/messages'), MessageModel.fromJson);

  // POST /api/orders/:id/messages
  Future<MessageModel> sendMessage(String orderId, String text) async =>
      MessageModel.fromJson(objectOf(await _api.post('/orders/$orderId/messages', {'text': text.trim(), 'type': 'text'})));

  // PUT /api/orders/:id/messages/read
  Future<void> markMessagesRead(String orderId) => _api.put('/orders/$orderId/messages/read');
}
