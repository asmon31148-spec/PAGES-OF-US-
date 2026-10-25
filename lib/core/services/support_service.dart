import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/app_constants.dart';

class SupportTicket {
  final String id;
  final String userId;
  final String userEmail;
  final String userNickname;
  final String? spaceId;
  final String message;
  final String category;
  final DateTime createdAt;

  SupportTicket({
    required this.id,
    required this.userId,
    required this.userEmail,
    required this.userNickname,
    this.spaceId,
    required this.message,
    this.category = 'General Support',
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'userEmail': userEmail,
      'userNickname': userNickname,
      'spaceId': spaceId,
      'message': message,
      'category': category,
      'createdAt': createdAt.toIso8601String(),
      'platform': 'Android Flutter Native',
      'status': 'open',
    };
  }
}

class SupportService {
  static const String defaultAdminEmail = 'asmon31148@gmail.com';

  /// Sends support complaint to Firestore, Supabase fallback, and dispatches email notification
  static Future<bool> sendTicket({
    required String userId,
    required String userEmail,
    required String userNickname,
    String? spaceId,
    required String message,
    String category = 'User Feedback / Complaint',
    String? customAdminEmail,
  }) async {
    final ticketId = 'ticket_${DateTime.now().millisecondsSinceEpoch}';
    final ticket = SupportTicket(
      id: ticketId,
      userId: userId,
      userEmail: userEmail,
      userNickname: userNickname,
      spaceId: spaceId,
      message: message,
      category: category,
      createdAt: DateTime.now(),
    );

    bool firestoreOk = false;
    bool emailOk = false;

    // 1. Save ticket in Firestore
    try {
      await FirebaseFirestore.instance
          .collection('support_tickets')
          .doc(ticketId)
          .set(ticket.toJson());
      firestoreOk = true;
    } catch (_) {}

    // 2. Fallback save in Supabase
    try {
      final supabase = Supabase.instance.client;
      await supabase.from('app_content').upsert({
        'id': 'support_$ticketId',
        'content': ticket.toJson(),
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {}

    // 3. Dispatch email notification to admin via FormSubmit
    try {
      final recipient = customAdminEmail ?? defaultAdminEmail;
      final uri = Uri.parse('https://formsubmit.co/ajax/$recipient');
      final resp = await http.post(
        uri,
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({
          'name': '$userNickname ($userEmail)',
          'email': userEmail,
          '_subject': '🌿 Pages of Us Complaint / Feedback from $userNickname',
          'category': category,
          'message': message,
          'userId': userId,
          'spaceId': spaceId ?? 'None',
          'submittedAt': DateTime.now().toIso8601String(),
        }),
      );
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        emailOk = true;
      }
    } catch (_) {}

    return firestoreOk || emailOk;
  }
}
