# Strata

A local-first notes app for Android, built with Flutter.

Strata is a rich-text note-taking app designed for fast writing, clean organization, and local ownership of your data. It focuses on a simple writing experience while supporting folders, tags, wiki-style links, attachments, reminders, and export options.

> **Platform note:** Strata is currently developed and tested on **Android devices only**.

## Features

- **Rich text editor** - Write with formatting, headings, lists, tables, dividers, and embedded images.
- **Image support** - Insert images from files, paste images from the clipboard, or share images into the app.
- **Code-friendly paste** - Preserves formatting when pasting content, including code-like text pasted as code blocks for readability.
- **Organization** - Manage notes with folders, tags, pinned notes, trash, and planned/due views.
- **Wiki links** - Connect notes using `[[Note Title]]` syntax for quick navigation between related notes.
- **Attachments** - Attach files to notes and view them inside the app.
- **Reminders** - Set due dates and local reminder notifications.
- **Templates** - Save reusable note templates for repeated workflows.
- **Export** - Export notes as PDF, Markdown, or Word (`.docx`).
- **Local-first storage** - Notes are stored locally on-device.

## Tech Stack

- **Flutter / Dart**
- **flutter_quill** - Rich text editor
- **Riverpod** - State management
- **Isar Community** - Local database/storage
- **go_router** - Navigation/routing

## Getting Started

### Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install) (Dart `^3.12.2`)
- Android Studio / Android SDK
- An Android device or emulator

### Run Locally

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

### Build Release APK

```bash
flutter build apk --release
```

The generated APK will be available at:

```text
build/app/outputs/flutter-apk/app-release.apk
```

## Project Structure

```text
lib/
  app/         # App shell, router, theme
  core/        # Shared widgets and utilities
  data/        # Models, repositories, services, database
  features/    # Feature screens (editor, home, search, settings, etc.)
  providers/   # Riverpod providers
```

## Testing

```bash
flutter test
```

## Author

**Kyle Tristan D. Turno**  
4th Year BSIT Student  
COMTEQ Computer and Business College, Inc.

## License

This project is licensed under the [MIT License](LICENSE).