# FitNation Mobile

> FBOS Mobile — Flutter customer app for the Fitness Business Operating System
> Workout tracking, diet plans, bookings, progress, chat, push notifications

## Tech Stack
- **Framework:** Flutter (stable channel) + Dart
- **Navigation:** GoRouter
- **Networking:** Dio + Retrofit
- **State:** Riverpod
- **Local Storage:** Hive/Isar (offline-first)
- **Charts:** fl_chart
- **Push Notifications:** Firebase Cloud Messaging
- **Testing:** flutter_test, integration_test

## Getting Started
```bash
flutter pub get
flutter run
```

## Testing
```bash
# Run all tests with coverage
flutter test --coverage

# Run specific tests
flutter test test/features/auth/

# Analyze
dart analyze
```

## Related Repos
- Backend: https://github.com/sirajudheen53/fitnation-backend
- Frontend: https://github.com/sirajudheen53/fitnation-frontend