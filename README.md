# 📚 Stidfy

**CoachFlow** is a Flutter-based mobile application designed for private tutors and coaching institute teachers to manage their classes end-to-end — from student enrollment and daily attendance to fee tracking and test marks — all backed by Firebase.

---

## 🧩 The Problem It Solves

Running a private tuition class or a small coaching institute involves a surprising amount of administrative work that most teachers handle manually — through paper registers, WhatsApp messages, or scattered spreadsheet files. This leads to:

- **Lost attendance records** — paper registers get damaged, misplaced, or become impossible to search through.
- **Fee confusion** — teachers struggle to track who has paid, who owes fees for multiple months, and what the total collected amount is.
- **No student history** — there's no easy way to look back at a student's attendance percentage or test performance over time.
- **Batch chaos** — managing multiple batches (e.g., "Grade 10 Maths – Morning" vs "Grade 12 Physics – Evening") with different schedules and fee structures is error-prone without a dedicated tool.
- **Wasted time** — teachers spend evenings doing admin instead of preparing lessons.

**CoachFlow solves this** by giving every teacher a personal, cloud-synced digital classroom manager that handles all of this automatically — accessible from their phone, at any time.

---

## ✨ Features

### 🔐 Authentication
- Email/password sign-up and login via Firebase Authentication.
- Each teacher gets an isolated, secure data space in Firestore.
- Persistent login — the app remembers the session across restarts.

### 🏠 Dashboard
- Personalized greeting banner with the current date.
- **Today's Overview** analytics grid showing live stats across all batches.
- **Next Action Card** — contextual guidance that tells the teacher what to do next (e.g., "You have no students yet — add one").
- Full list of all created batches with subject, schedule, monthly fee, start date, and duration.
- **Quick Actions** panel: one-tap shortcuts to Add Student, Mark Attendance, Record Payment, Create Batch, and Add Test Marks.
- Onboarding guide for first-time users — step-by-step prompts to create a batch and add students.

### 📦 Batch Management
- Create batches with: name, subject, weekly schedule, monthly fee, start date, and total duration in months.
- Computed **total fee** from `monthly fee × duration months`.
- Delete batches.
- Real-time Firestore stream — changes appear instantly without a page refresh.

### 👩‍🎓 Student Management
- Add students to a batch with: name, parent email, parent phone, roll number, and initial fees due.
- Deactivate students (soft delete — data is preserved).
- View all students filtered by batch.
- Per-student detail screen with full profile, attendance calendar, and payment history.

### ✅ Attendance
- Mark attendance (present/absent) per student per date.
- **Visual attendance calendar** — full monthly grid with color-coded cells:
  - 🟢 Green with a check — present on a scheduled class day.
  - 🔴 Red with a diagonal cross — absent on a scheduled class day.
  - ⬜ Grey — non-class day (weekend or outside schedule).
  - Light grey — future dates (no action yet).
- Attendance percentage ring per student.
- Schedule-aware: only marks class days based on the batch's weekly schedule (e.g., Mon/Wed/Fri).

### 💰 Fee Management
- Track `fees_due` and `fees_paid` per student.
- Record payments — each payment is logged with timestamp and student reference.
- Mark a student's monthly fee as fully paid.
- Monthly fee reset logic — fees are only re-applied if the current month hasn't been marked paid yet.
- View outstanding dues across all students in a batch.

### 📝 Test Marks
- Add test marks per student per batch.
- Select a batch, then enter marks for each student in a single flow.
- Marks are stored per student and viewable in the student detail screen.

### 👤 Profile Screen
- Displays teacher name and email from Firestore.
- Sign-out button.

---

## 🛠 Tech Stack

| Layer | Technology |
|---|---|
| Framework | Flutter (Material 3) |
| Language | Dart |
| Authentication | Firebase Authentication |
| Database | Cloud Firestore |
| State Management | `StreamBuilder` / `setState` (reactive Firestore streams) |
| Architecture | Feature-based single-file UI with separated Backend helpers |

---

## 🗂 Project Structure

```
lib/
├── main.dart                  # All UI screens and widgets
Backend/
├── AuthManager.dart           # Firebase Auth: sign up, sign in, sign out
├── database_helper.dart       # Firestore CRUD: batches, students, attendance, fees, payments
```

The project follows a clear two-layer architecture:
- **UI layer** (`main.dart`) — all widgets, layouts, and screens. Labeled with `// UI:` comments throughout.
- **Backend layer** (`Backend/`) — all Firestore and Auth logic. Labeled with `// Backend:` comments. To change any data behavior, only edit files here.

---

## 🔥 Firestore Data Model

```
teachers/
  {teacherId}/
    ├── name
    ├── email
    ├── created_at
    ├── batches/
    │     {batchId}/
    │       ├── name
    │       ├── subject
    │       ├── schedule
    │       ├── monthly_fee
    │       ├── start_date
    │       ├── duration_months
    │       ├── total_days
    │       └── last_attendance_date
    ├── students/
    │     {studentId}/
    │       ├── name
    │       ├── parent_email
    │       ├── parent_phone
    │       ├── batch_id
    │       ├── roll_no
    │       ├── join_date
    │       ├── fees_due
    │       ├── fees_paid
    │       ├── last_fee_paid_month
    │       ├── present_days
    │       ├── is_active
    │       └── attendance/
    │             {dateISO}/
    │               ├── date
    │               └── present
    └── payments/
          {paymentId}/
            ├── student_id
            ├── amount
            └── paid_on
```

---

## 🚀 Getting Started

### Prerequisites

- Flutter SDK ≥ 3.0
- A Firebase project with **Authentication** and **Firestore** enabled
- FlutterFire CLI (for `firebase_options.dart` generation)

### Setup

1. **Clone the repository**
   ```bash
   git clone https://github.com/your-username/coachflow.git
   cd coachflow
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Connect Firebase**

   Install the FlutterFire CLI and run:
   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```
   This generates `lib/firebase_options.dart` — do **not** commit this file to a public repo.

4. **Enable Firebase services**

   In the [Firebase Console](https://console.firebase.google.com):
   - Go to **Authentication → Sign-in method** → Enable **Email/Password**.
   - Go to **Firestore Database** → Create a database in production mode.

5. **Firestore Security Rules** (recommended minimum)
   ```js
   rules_version = '2';
   service cloud.firestore {
     match /databases/{database}/documents {
       match /teachers/{teacherId}/{document=**} {
         allow read, write: if request.auth != null && request.auth.uid == teacherId;
       }
     }
   }
   ```

6. **Run the app**
   ```bash
   flutter run
   ```

---

## 🎨 Theming

All colors are defined in a single `AppColors` class at the top of `main.dart`. To retheme the entire app, only edit values there — no need to hunt through widget trees.

```dart
class AppColors {
  static const primary    = Color(0xFF4A90E2);
  static const success    = Color(0xFF43A047);
  static const warning    = Color(0xFFF5A623);
  static const error      = Color(0xFFE53935);
  // ...
}
```

---

## 📦 Key Dependencies

Add these to your `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  firebase_core: ^latest
  firebase_auth: ^latest
  cloud_firestore: ^latest
```

---

## 🤝 Contributing

Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.

1. Fork the repo
2. Create your feature branch (`git checkout -b feature/your-feature`)
3. Commit your changes (`git commit -m 'Add some feature'`)
4. Push to the branch (`git push origin feature/your-feature`)
5. Open a Pull Request

---

## 📄 License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgements

Built with [Flutter](https://flutter.dev) and [Firebase](https://firebase.google.com).
