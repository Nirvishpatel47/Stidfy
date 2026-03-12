import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DatabaseHelper {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String teacherId = FirebaseAuth.instance.currentUser!.uid;

  // Backend: adds a new batch with fee duration for total fee calculation
  Future<void> addBatch({
    required String name,
    required String subject,
    required String schedule,
    required double monthlyFee,
    required DateTime startDate,      // NEW
    required int durationMonths,      // NEW
  }) async {
    await _db
        .collection("teachers")
        .doc(teacherId)
        .collection("batches")
        .add({
      "name": name,
      "subject": subject,
      "schedule": schedule,
      "monthly_fee": monthlyFee,
      "start_date": Timestamp.fromDate(startDate),   // NEW
      "duration_months": durationMonths,              // NEW
      "total_days": 0,
      "last_attendance_date": null,
      "created_at": FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteBatch(String batchId) async {
    await _db
        .collection("teachers")
        .doc(teacherId)
        .collection("batches")
        .doc(batchId)
        .delete();
  }

  Stream<QuerySnapshot> getBatches() {
    return FirebaseFirestore.instance
        .collection("teachers")
        .doc(FirebaseAuth.instance.currentUser!.uid)
        .collection("batches")
        .snapshots();
  }

  Future<void> addStudent({ required String name, required String parentEmail, String parentPhone = "None", required String batchId, String rollno = "None", required double feesDue, }) async {
    await _db
        .collection("teachers")
        .doc(teacherId)
        .collection("students")
        .add({
        "name": name,
        "parent_email": parentEmail,
        "parent_phone": parentPhone,
        "batch_id": batchId,
        "roll_no": rollno,
        "fees_due": feesDue,
        "fees_paid": 0.0,
        "present_days": 0,
        "last_marked_date": null,
        "is_active": true,
        "created_at": FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateStudentFees({ required String studentId, required double feesPaid, }) async {
    final studentRef = _db
        .collection("teachers")
        .doc(teacherId)
        .collection("students")
        .doc(studentId);

    final doc = await studentRef.get();
    double currentPaid = doc["fees_paid"] ?? 0.0;

    await studentRef.update({
      "fees_paid": currentPaid + feesPaid,
    });
  }

  Future<void> deactivateStudent(String studentId) async {
    await _db
        .collection("teachers")
        .doc(teacherId)
        .collection("students")
        .doc(studentId)
        .update({"is_active": false});
  }

  Future<void> markAttendance({ required String studentId, required DateTime date, required bool present, }) async {
    await _db
        .collection("teachers")
        .doc(teacherId)
        .collection("students")
        .doc(studentId)
        .collection("attendance")
        .doc(date.toIso8601String())
        .set({
      "date": Timestamp.fromDate(date),
      "present": present,
    });
  }

  Future<void> addPayment({ required String studentId, required double amount,}) async {
    await _db
        .collection("teachers")
        .doc(teacherId)
        .collection("payments")
        .add({
      "student_id": studentId,
      "amount": amount,
      "paid_on": FieldValue.serverTimestamp(),
    });

    // Update student's paid amount
    await updateStudentFees(
      studentId: studentId,
      feesPaid: amount,
    );
  }
}
