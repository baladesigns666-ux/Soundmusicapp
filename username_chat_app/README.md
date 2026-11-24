# VibeHandle — Username-Based Chat App (Flutter UI + Firebase Ready)

A sleek, modern username-based (`@handle`) chat application built with Flutter and wired with Firebase initialization (`firebase_core` + `cloud_firestore` service layer).

## How Chats Currently Work (UI Prototype)
1. **Claim `@username` (`username_login_screen.dart`):** Enter a display name and `@username` handle (sanitized to lowercase `a-z0-9_.`).
2. **Chat List & `@handle` Search (`chat_home_screen.dart`):**
   - Loads initial sample threads (`@arjun_dev`, `@kavya_ui`, `@karthik_ops`) from `lib/models/chat_models.dart`.
   - Filtering searches by `@username` or display name.
   - Typing a new `@username` shows **"Start chat with @handle"**, which creates a `ChatThread` in memory and opens `ChatRoomScreen`.
3. **Chat Room (`chat_room_screen.dart`):**
   - Appends sent `ChatMessage` items to `thread.messages` and updates the UI via `setState`.
   - Runs a 900ms `Timer` to show a `typing...` indicator and append a simulated reply (`Got your message on @handle!`).
   - Note: Because messages are held in memory (`ChatThread.messages`), closing/restarting the app resets new chats unless connected to Firestore.

## Firebase Setup
1. Install FlutterFire CLI and run `flutterfire configure` inside `username_chat_app/` to generate `lib/firebase_options.dart` (or place `google-services.json` under `android/app/`).
2. Run `flutter pub get`.
3. Run `flutter run`.
