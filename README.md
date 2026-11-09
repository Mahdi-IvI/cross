# DMS mobile app

Flutter client for this repository's .NET API. Targets Android and iOS.

## Features

- Login, registration, secure session restoration, editable profile and one fixed API URL.
- Nested folders, breadcrumbs, document details, local search, sorting and list/grid layouts.
- Create, rename, move and delete documents/folders using the actual API contracts.
- File picker with streaming to disk and upload/download feedback.
- Photo capture, video recording and photo-library selection through `image_picker`, using the same upload form and document queue.
- Offline metadata browsing, saved file opening, favorites and a persistent operation queue.
- Document scanning with native crop/perspective correction, image import, page ordering, rotation, grayscale/black-and-white filters and multi-page PDF export.
- Automatic synchronization on startup, app resume, connectivity changes and every 30 seconds while the library is active; manual retry is also available.

The imported `pnw` feature was ported to DMS rather than carrying over its missing workspace/permission infrastructure. Bookmarks, version history and checkout from that source are not exposed by this backend. The scanner has been ported separately under `features/documentScanner/` and creates normal PDF documents through the existing upload queue.

## Photo and video uploads

Inside the desired folder, use **New → Upload document**, **Take photo**, **Record video**, or **Photo library**. File selection or camera capture happens first. After a file is selected, the upload form opens with its name prefilled; enter a description and tap **Save & upload**. Cancelling selection keeps the library open. The form only contains name, description and the upload button; opening `/upload` without a selected file returns to the library.

Captured media is temporary until the user confirms the upload. Confirmation copies the file into the existing durable document upload queue before deleting the camera copy; leaving the form discards temporary media. A failed handoff keeps the capture available for retry. No application-defined file-size or recording-duration limit is set.

On Android, media returned after the OS restarts the app during capture is recovered at startup after sign-in. The upload form reopens at **All files**, allowing the user to review it before uploading. The original folder cannot be restored after process death. iOS declares camera, microphone and photo-library usage descriptions. Access is requested by the native picker when needed. Real camera/video recording requires a physical-device check.

## Document scanner

Open **New → Scan document** inside the desired folder. Tap **Scan pages** for the native camera scanner or **Import images** for existing JPEG/PNG files. The app does not impose a total page limit; native scanner and device capabilities still apply. Tap a page to choose Original/Gray/B&W and rotate it; drag its handle to reorder pages or use its delete button to remove it.

Pages and edits exist only for the open scanner session. Going back discards them and removes temporary images; there are no saved scan drafts or scan records in ObjectBox. **Save PDF & upload** builds a compressed A4 PDF off the UI isolate, copies the finished PDF into the existing document upload queue, then closes the scanner and removes its temporary files. Files and generated PDFs have no application-defined upload-size cap.

Camera access is requested by the native scanner only after tapping **Scan pages**; iOS declares `NSCameraUsageDescription`. Android uses the Google Play services document scanner and may need an initial online module download. Android `content://` scan results are copied through a bounded app-private native bridge. Unsupported devices/camera denial leave the current pages and image import available. The iOS simulator has no document camera; native automated tests use generated images to exercise temporary processing, PDF creation and backend upload/download. Widget tests cover the scanner and editor UI. Optical capture still requires a physical-device check.

## Run

Requires Flutter 3.47 / Dart 3.13.7 or a compatible newer SDK, and native Android/iOS tooling.

Start the backend from the repository root:

```bash
docker compose up -d --build
```

Then:

```bash
cd app
flutter pub get
dart run build_runner build
flutter run
```

The generated `lib/objectbox.g.dart` and `lib/objectbox-model.json` are committed source artifacts. Keep the model's UIDs stable; regenerate bindings after changing database entities.

The API URL is fixed in `lib/core/config/app_config.dart`. Set this constant to the backend address reachable from your phone, including the `/api/` suffix. The app has no server selector, saved server preference or build-time URL override. For a deployment, change this single constant to the backend's reachable URL before building. The provided development account is `admin` / `admin123`.

When using `http://localhost:5176/api/`, localhost works with the iOS simulator. For an Android development device/emulator connected by USB and using localhost, forward its API port before launching:

```bash
adb reverse tcp:5176 tcp:5176
```

For a physical phone without port forwarding, set the constant to the computer's LAN URL and rebuild; the phone and server must be reachable on the same network.

Android has Internet/HTTP configuration for the coursework server; iOS allows local networking and declares its local-network usage. Use an HTTPS server for a deployed environment. iOS targets 15.0+. ObjectBox uses CocoaPods on iOS, so CocoaPods and Xcode are needed to build it. Signing for a physical iPhone remains a normal local Xcode setup step.

## Architecture

```text
lib/
  core/
    config/        Fixed API URL
    database/      ObjectBox store and persistence entities
    errors/        Application failures
    network/       Dio client with fixed URL, direct auth headers and error mapping
    routing/       GoRouter and authentication guards
    theme/         Material 3 theme
  features/
    auth/
      domain/      Session and repository contract
      data/        API authentication and Keychain/Keystore-backed session storage
      presentation/ Riverpod authentication controller and sign-in/register UI
    document/
      domain/      Immutable entities, repository contract and application use cases
      data/        API/local data sources, mapping and offline repository
      presentation/ Riverpod streams/sync controller, pages and widgets
    documentScanner/
      domain/      Scanned page and filter values
      data/        Native image acquisition and temporary image/PDF processing
      presentation/ Riverpod session state
    settings/
      presentation/Profile, synchronization and offline-file management
```

Name and description are validated by the shared domain entity `ItemDetails`, used by application use cases, the document repository and PDF upload. The scanned-page editor applies rotation/filter choices synchronously in memory; only preview processing remains asynchronous.

The domain layer has no Flutter, Dio, Riverpod or ObjectBox dependencies. Riverpod composes implementations and manages session, library and synchronization state. GoRouter protects the library, upload, scanner, details and settings routes. HTTP requests use ordinary Dio options; authentication failures are handled explicitly without custom interceptors. Widgets invoke domain use cases rather than calling HTTP or database APIs.

## Offline behavior

- ObjectBox stores metadata, favorites and pending operations. Binary files are in the application's private support directory, rather than temporary picker locations.
- Cache and file directories are scoped by a hash of the fixed API URL and authenticated username. Another account cannot query or open those cached items through the app.
- Local IDs remain stable across synchronization. Server IDs are stored separately and resolved for parent relationships and API calls.
- Create/update/delete operations are queued transactionally. Edits coalesce into a pending create/upload. Pending parents are created first; recursive deletions process descendants before parents. Failed changes stay queued with an error and can be retried.
- Uploads copy the source file into app storage before committing metadata and the outbox together. The source may be removed or its picker permission expire without losing the queued upload.
- Downloads are written to a temporary file, checked against the expected size and renamed on completion. Once saved, opening a file works offline.
- **Remove offline files** removes downloaded copies but keeps pending uploads and metadata. Signing out clears the secure session, while each account's cache and pending queue remain for the next sign-in.
- Synchronization runs while the app is active; this app does not install an OS background worker. A valid restored session is needed for offline access. A server 401 signs the user out and requires authentication again.

The backend currently has no request-id deduplication or edit revisions. A create/upload whose response is lost after the server accepted it can be duplicated by a retry, and concurrent edits use the API's last-write behavior. The client preserves failed operations instead of silently discarding them. Actual OCR/summarization still depends on implementing the backend worker.

## Verification

The app targets Android and iOS only. No macOS app target or build is required.

```bash
flutter analyze
flutter test test/auth_session_test.dart test/widget_test.dart test/scanner_widget_test.dart test/upload_source_picker_test.dart test/media_upload_widget_test.dart test/item_details_test.dart
flutter build apk --debug
flutter build ios --simulator --debug
```

Database-backed host tests (`flutter test` for the full suite, including the optional backend test below) need a separately installed ObjectBox native library for the host OS. That library is not kept in this project. The mobile integration test below uses the bundled iOS/Android runtime instead.

The ordinary suite covers real ObjectBox restart persistence, queue ordering/coalescing, folder moves/cycles, recursive deletions, account isolation, offline downloads, cache cleanup, authentication guards, search and phone/tablet layouts. The optional backend test creates a uniquely named temporary folder in the development account, uploads and downloads exact bytes, edits/moves the document, then deletes its test data.

Override integration credentials when needed:

```bash
flutter test test/backend_integration_test.dart \
  --dart-define=DMS_RUN_BACKEND_TESTS=true \
  --dart-define=DMS_TEST_USERNAME=admin \
  --dart-define=DMS_TEST_PASSWORD=admin123
```

A native device integration test also exercises the actual Flutter engine, secure storage, ObjectBox and UI against the API:

```bash
flutter test integration_test/native_app_test.dart -d <simulator-id>
```

The scanner tests cover temporary-file cleanup, corrupt-image rollback, scans with more than twenty pages, image transforms, multi-page PDF generation and a completed PDF surviving scan cleanup in the document upload queue. UI tests verify folder selection, camera failure, editing, upload and an empty scanner session after leaving and reopening.

Media tests cover exact photo/video bytes, filenames, destination folders, cancellation, permission denial, failed-upload retries, temporary-file cleanup and recovery after Android process death.

The library navigation has Files and Favorites. Downloaded files can still be opened from document details and cleared from Settings. Legacy `?view=offline` links fall back to Files. Selection and recovery tests cover cancellation before navigation, denied permissions, signing out during selection and failed recovery without an empty upload form.
