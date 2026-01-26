# Music Workout MVP

A Flutter app for music practice, inspired by fitness workout apps. Teachers create practice plans with sessions and exercises, assign them to students, and track progress.

## Features

### Teacher
- Create practice plans with sessions and exercises
- Assign plans to students by email
- View student progress (practice logs, completion stats)

### Student
- View assigned practice plans
- Session player with timer, next/back navigation
- Mark exercises complete (creates practice log)

## Tech Stack

- **Flutter** (latest stable)
- **Firebase**: Auth, Firestore
- **State Management**: Riverpod
- **Navigation**: go_router

## Project Structure

```
lib/
├── main.dart                 # Entry point
├── app.dart                  # MaterialApp + Router
├── firebase_options.dart     # Firebase config (generated)
├── core/
│   └── theme.dart            # Material 3 theme
├── models/
│   └── models.dart           # All data models
├── services/
│   └── firebase_service.dart # Firebase operations
├── providers/
│   └── providers.dart        # Riverpod providers
├── router/
│   └── router.dart           # GoRouter configuration
└── screens/
    ├── auth/                 # Login, Signup, Role selection
    ├── teacher/              # Teacher screens
    └── student/              # Student screens
```

## Setup Instructions

### 1. Prerequisites

- Flutter SDK (3.5.0 or later)
- Firebase CLI
- FlutterFire CLI

```bash
# Install FlutterFire CLI
dart pub global activate flutterfire_cli
```

### 2. Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Create a new project
3. Enable **Authentication** > Sign-in method > Email/Password
4. Create **Firestore Database** (start in test mode)

### 3. Configure Firebase

```bash
# Navigate to project directory
cd "MVP ChopZ"

# Configure Firebase (generates firebase_options.dart)
flutterfire configure --project=YOUR_PROJECT_ID
```

### 4. Install Dependencies

```bash
flutter pub get
```

### 5. Set Up Firestore Security Rules

In Firebase Console > Firestore > Rules, paste:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Helper function to check if user is authenticated
    function isAuthenticated() {
      return request.auth != null;
    }
    
    // Helper function to check if user owns the document
    function isOwner(userId) {
      return request.auth.uid == userId;
    }
    
    // Users collection
    match /users/{userId} {
      allow read: if isAuthenticated();
      allow create: if isOwner(userId);
      allow update: if isOwner(userId);
    }
    
    // Plans collection
    match /plans/{planId} {
      allow read: if isAuthenticated();
      allow create: if isAuthenticated() && request.resource.data.teacherId == request.auth.uid;
      allow update, delete: if isAuthenticated() && resource.data.teacherId == request.auth.uid;
      
      // Sessions subcollection
      match /sessions/{sessionId} {
        allow read: if isAuthenticated();
        allow write: if isAuthenticated() && get(/databases/$(database)/documents/plans/$(planId)).data.teacherId == request.auth.uid;
        
        // Exercises subcollection
        match /exercises/{exerciseId} {
          allow read: if isAuthenticated();
          allow write: if isAuthenticated() && get(/databases/$(database)/documents/plans/$(planId)).data.teacherId == request.auth.uid;
        }
      }
    }
    
    // Assignments collection
    match /assignments/{assignmentId} {
      allow read: if isAuthenticated() && (
        resource.data.teacherId == request.auth.uid || 
        resource.data.studentId == request.auth.uid
      );
      allow create: if isAuthenticated() && request.resource.data.teacherId == request.auth.uid;
      allow update, delete: if isAuthenticated() && resource.data.teacherId == request.auth.uid;
    }
    
    // Practice logs collection
    match /practiceLogs/{logId} {
      allow read: if isAuthenticated() && (
        resource.data.studentId == request.auth.uid || 
        resource.data.teacherId == request.auth.uid
      );
      allow create: if isAuthenticated() && request.resource.data.studentId == request.auth.uid;
    }
  }
}
```

### 6. Create Firestore Indexes

In Firebase Console > Firestore > Indexes, create:

| Collection | Fields | Query scope |
|------------|--------|-------------|
| `plans` | `teacherId` Asc, `createdAt` Desc | Collection |
| `assignments` | `teacherId` Asc, `assignedAt` Desc | Collection |
| `assignments` | `studentId` Asc, `assignedAt` Desc | Collection |
| `practiceLogs` | `studentId` Asc, `startedAt` Desc | Collection |
| `practiceLogs` | `teacherId` Asc, `startedAt` Desc | Collection |

### 7. Run the App

```bash
# iOS (requires Xcode)
flutter run -d ios

# Android
flutter run -d android
```

## Firestore Data Model

```
users/{userId}
├── email: string
├── displayName: string
├── role: 'teacher' | 'student'
└── createdAt: timestamp

plans/{planId}
├── teacherId: string
├── title: string
├── description: string
├── instrument: string
├── difficulty: 'beginner' | 'intermediate' | 'advanced'
├── published: boolean
├── createdAt: timestamp
└── sessions/{sessionId}
    ├── title: string
    ├── orderIndex: number
    ├── estMinutes: number
    └── exercises/{exerciseId}
        ├── title: string
        ├── instructions: string
        ├── orderIndex: number
        ├── targetBpm: number (optional)
        ├── targetSeconds: number (optional)
        └── attachmentUrls: string[]

assignments/{assignmentId}
├── teacherId: string
├── studentId: string
├── studentEmail: string
├── planId: string
└── assignedAt: timestamp

practiceLogs/{logId}
├── studentId: string
├── teacherId: string
├── planId: string
├── sessionId: string
├── exerciseId: string
├── startedAt: timestamp
├── completedAt: timestamp
└── durationSeconds: number
```

## Routes

### Auth
- `/login` - Login screen
- `/signup` - Registration screen
- `/role` - Role selection (teacher/student)

### Teacher
- `/teacher/home` - Plans list
- `/teacher/plan/new` - Create new plan
- `/teacher/plan/:id/edit` - Edit plan + view sessions
- `/teacher/plan/:id/session/new` - Create session
- `/teacher/plan/:id/session/:id` - Edit session + view exercises
- `/teacher/plan/:id/session/:id/exercise/new` - Create exercise
- `/teacher/plan/:id/session/:id/exercise/:id` - Edit exercise
- `/teacher/assign` - Assign plans to students
- `/teacher/student/:id/progress` - View student progress

### Student
- `/student/home` - Assigned plans list
- `/student/plan/:id` - Plan detail + sessions list
- `/student/plan/:id/session/:id/player` - Session player (workout mode)

## License

MIT
