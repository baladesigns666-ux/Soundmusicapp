import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../firebase_options.dart';

class FirebaseChatService {
  FirebaseChatService._();

  static bool isInitialized = false;
  static String? initError;

  static Future<void> initialize() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      isInitialized = true;
      initError = null;
    } catch (e) {
      // Allows UI preview to still launch cleanly before `flutterfire configure`
      // is run or real Firebase credentials are added.
      isInitialized = false;
      initError = e.toString();
    }
  }

  static FirebaseFirestore get firestore => FirebaseFirestore.instance;

  /// Deterministic room ID for two `@username` handles so A <-> B always
  /// share the same thread document.
  static String buildRoomId(String userA, String userB) {
    final a = userA.trim().toLowerCase().replaceAll('@', '');
    final b = userB.trim().toLowerCase().replaceAll('@', '');
    final sorted = [a, b]..sort();
    return '${sorted[0]}__${sorted[1]}';
  }

  static Future<void> registerUsername({
    required String username,
    required String displayName,
  }) async {
    if (!isInitialized) return;
    final cleanHandle = username.trim().toLowerCase().replaceAll('@', '');
    await firestore.collection('usernames').doc(cleanHandle).set({
      'username': cleanHandle,
      'displayName': displayName.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> sendMessageToFirestore({
    required String currentUsername,
    required String peerUsername,
    required String text,
  }) async {
    if (!isInitialized) return;
    final me = currentUsername.trim().toLowerCase().replaceAll('@', '');
    final peer = peerUsername.trim().toLowerCase().replaceAll('@', '');
    final roomId = buildRoomId(me, peer);

    final roomRef = firestore.collection('chat_rooms').doc(roomId);
    await roomRef.set({
      'participants': [me, peer],
      'lastMessage': text,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await roomRef.collection('messages').add({
      'senderUsername': me,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> messageStream({
    required String currentUsername,
    required String peerUsername,
  }) {
    final roomId = buildRoomId(currentUsername, peerUsername);
    return firestore
        .collection('chat_rooms')
        .doc(roomId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .snapshots();
  }
}
