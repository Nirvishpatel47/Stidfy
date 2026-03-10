//main.dart

//import statements
import 'Backend/database_helper.dart';
import 'Backend/AuthManager.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

//main function. Don't ouch this.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const CoachFlowApp());
}

//Authentication and login
//Don't change for it now
class CoachFlowApp extends StatelessWidget {
  const CoachFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          if (snapshot.hasData) return const MainDashboard();
          return const AuthScreen();
        },
      ),
    );
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

//Authentication screen
//Same don/t change now
class _AuthScreenState extends State<AuthScreen> {
  bool _isLogin = true;
  bool _isLoading = false;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  final AuthServices _authServices = AuthServices();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();

    if (email.isEmpty || password.isEmpty || (!_isLogin && name.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("All fields are required")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_isLogin) {
        await _authServices.signIn(
          email: email,
          password: password,
        );
      } else {
        await _authServices.signUp(
          name: name,
          email: email,
          password: password,
        );
      }
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? "Authentication failed")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Something went wrong")),
      );
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _isLogin ? "Teacher Login" : "Register",
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            if (!_isLogin)
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: "Full Name"),
              ),

            if (!_isLogin) const SizedBox(height: 10),

            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: "Email"),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 10),

            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: "Password"),
              obscureText: true,
            ),
            const SizedBox(height: 20),

            _isLoading
                ? const CircularProgressIndicator()
                : SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submit,
                      child: Text(_isLogin ? "Login" : "Sign Up"),
                    ),
                  ),

            TextButton(
              onPressed: () {
                setState(() => _isLogin = !_isLogin);
              },
              child: Text(
                _isLogin
                    ? "New here? Register"
                    : "Have an account? Login",
              ),
            ),
          ],
        ),
      ),
    );
  }
}

//Main Dashboard
class MainDashboard extends StatefulWidget {
  const MainDashboard({Key? key}) : super(key: key);

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {

  //Backend component (Don't touch)
  int _currentIndex = 0;

  //Backend component (Don't touch)
  final List<Widget> _pages = [
    DashboardScreen(),
    AttendanceScreen(),
    PaymentScreen(),
    profile(), // Use proper class name
  ];

  @override
  Widget build(BuildContext context) {
    //UI
    return Scaffold(
      //backgroundColor: const Color(0xFF0F172A), // Deep dark blue
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 27, 27, 31), // Slightly lighter dark
        elevation: 0,
        title: const Text(
          "Dashboard",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        actions: [
          if (_currentIndex == 0)
            IconButton(
              icon: const Icon(Icons.add, color: Colors.white),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddBatch(),
                  ),
                );
              },
            ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton(
              backgroundColor: const Color(0xFF3B82F6), // Strong blue
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AddStudents(),
                  ),
                );
              },
              child: const Icon(Icons.person_add, color: Colors.white),
            )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF1E293B),
        selectedItemColor: const Color(0xFF3B82F6),
        unselectedItemColor: Colors.white54,
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: "Dashboard",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.check_circle),
            label: "Attendance",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.monetization_on_rounded),
            label: "Fees",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: "Profile",
          ),
        ],
      ),
    );
  }
}

//Dashboard screen
class DashboardScreen extends StatelessWidget {
  DashboardScreen({super.key});

  //Backend component (Don't touch)
  final String teacherId =
      FirebaseAuth.instance.currentUser!.uid;

  //Backend component (Don't touch)
  String get currentMonth { final now = DateTime.now(); return "${now.year}-${now.month.toString().padLeft(2, '0')}"; }

  //UI
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          const Text(
            "Dashboard",
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 16),

          /// STATS GRID
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            children: [

              _buildActiveStudentsCard(),
              _buildBatchesCard(),
              _buildCollectedCard(),
              _buildPendingStudentsCard(),
            ],
          ),
        ],
      ),
    );
  }

  /// 1️⃣ ACTIVE STUDENTS
  Widget _buildActiveStudentsCard() {
    return StreamBuilder<QuerySnapshot>(
      //Backend component (Don't touch)
      stream: FirebaseFirestore.instance
          .collection("teachers")
          .doc(teacherId)
          .collection("students")
          .where("is_active", isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {

        int count = snapshot.data?.docs.length ?? 0;

        //UI
        return _statCard(
          title: "Active Students",
          value: count.toString(),
          color: Colors.blue.shade50,
        );
      },
    );
  }

  /// 2️⃣ BATCH COUNT Backend component (Don't touch)
  Widget _buildBatchesCard() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("teachers")
          .doc(teacherId)
          .collection("batches")
          .snapshots(),
      builder: (context, snapshot) {

        int count = snapshot.data?.docs.length ?? 0;

        return _statCard(
          title: "Batches",
          value: count.toString(),
          color: Colors.orange.shade50,
        );
      },
    );
  }

  /// 3️⃣ TOTAL COLLECTED THIS MONTH Backend component (Don't touch)
  Widget _buildCollectedCard() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("teachers")
          .doc(teacherId)
          .collection("payments")
          .snapshots(),
      builder: (context, snapshot) {

        double total = 0;

        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            total += (doc["amount"] ?? 0);
          }
        }

        return _statCard(
          title: "Total Collected",
          value: "₹ ${total.toStringAsFixed(0)}",
          color: Colors.green.shade50,
        );
      },
    );
  }

  /// 4️⃣ STUDENTS WITH DUE Backend component (Don't touch)
  Widget _buildPendingStudentsCard() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("teachers")
          .doc(teacherId)
          .collection("students")
          .where("is_active", isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {

        int pending = 0;

        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            double paid = doc["fees_paid"] ?? 0;
            if (paid <= 0) pending++;
          }
        }

        return _statCard(
          title: "Pending Students",
          value: pending.toString(),
          color: Colors.red.shade50,
        );
      },
    );
  }

  /// COMMON CARD UI
  Widget _statCard({
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment:
            MainAxisAlignment.center,
        children: [
          Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 14)),
          const SizedBox(height: 8),
          Text(value,
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

//Add Students 
class AddStudents extends StatefulWidget {
  const AddStudents({super.key});

  @override
  State<AddStudents> createState() => _AddStudentsState();
}

class _AddStudentsState extends State<AddStudents> {
  //Backend component (Don't touch)
  final _nameController = TextEditingController();
  final _parentsEmailController = TextEditingController();
  final _parentPhoneController = TextEditingController();
  final _feesController = TextEditingController();
  final _rollnocontroller = TextEditingController();

  final _db = DatabaseHelper();

  String? selectedBatchId;

  //Backend component as well as UI handler
  @override
  void dispose() {
    _nameController.dispose();
    _parentsEmailController.dispose();
    _parentPhoneController.dispose();
    _feesController.dispose();
    super.dispose();
  }

  //Backend component 
  void _addStudent() async {
    final name = _nameController.text.trim();
    final parentEmail = _parentsEmailController.text.trim();
    final parentPhone = _parentPhoneController.text.trim();
    final feesDue = double.tryParse(_feesController.text.trim());
    final rollno = _rollnocontroller.text.trim();

    if (name.isEmpty || parentEmail.isEmpty || parentPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("All fields are required")),
      );
      return;
    }

    if (selectedBatchId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a batch")),
      );
      return;
    }

    if (feesDue == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter valid fee amount")),
      );
      return;
    }

    await _db.addStudent(
      name: name,
      parentEmail: parentEmail,
      parentPhone: parentPhone,
      batchId: selectedBatchId!,
      rollno: rollno,
      feesDue: feesDue,
    );

    //UI
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Student added Successfully successfully"),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );

    _nameController.clear();
    _parentPhoneController.clear();
    _parentsEmailController.clear();
    _feesController.clear();
    _rollnocontroller.clear;

    setState(() {
      selectedBatchId = null; // if using dropdown
    });

  }

  //UI but have backend to extract data
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add Student")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: "Student Name",
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _parentsEmailController,
                decoration: const InputDecoration(
                  labelText: "Email",
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _parentPhoneController,
                decoration: const InputDecoration(
                  labelText: "Phone (Optional)",
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _feesController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: "Fees Due",
                ),
              ),
              const SizedBox(height: 16),

              // Replace your batch text field with dropdown later
              StreamBuilder<QuerySnapshot>(
                stream: _db.getBatches(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const CircularProgressIndicator();
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Text("No batches found. Please create a batch first. From Top right '+' icon of dashboard.");
                  }

                  final batches = snapshot.data!.docs;

                  return DropdownButtonFormField<String>(
                    value: selectedBatchId,
                    decoration: const InputDecoration(
                      labelText: "Select Batch",
                      border: OutlineInputBorder(),
                    ),
                    items: batches.map((batch) {
                      return DropdownMenuItem<String>(
                        value: batch.id,
                        child: Text(batch["name"]),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedBatchId = value;
                      });
                    },
                  );
                },
              ),

              const SizedBox(height: 16,),
              TextField(
                controller: _rollnocontroller,
                decoration: const InputDecoration(
                  labelText: "RollNo (Optional)",
                ),
              ),

              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _addStudent,
                child: const Text("Add Student"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

//Add batch
class AddBatch extends StatefulWidget {
  const AddBatch({super.key});

  @override
  State<AddBatch> createState() => _AddBatchState();
}

class _AddBatchState extends State<AddBatch> {
  //Backend components
  final _namecontroller = TextEditingController();
  final _subjectcontroller = TextEditingController();
  final _shedulecontroller = TextEditingController();
  final _monthly_feesController = TextEditingController();
  final _db = DatabaseHelper();

  //Backend components
  @override
  void dispose() {
    _namecontroller.dispose();
    _subjectcontroller.dispose();
    _shedulecontroller.dispose();
    _monthly_feesController.dispose();
    super.dispose();
  }

  //Backend components
  void _addbatch() {
    final name = _namecontroller.text.trim();
    final subject = _subjectcontroller.text.trim();
    final shedule = _shedulecontroller.text.trim();
    final monthly_fee = double.tryParse(_monthly_feesController.text.trim());

    if (monthly_fee == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter valid number")),
      );
      return;
    }

    _db.addBatch(name: name, subject: subject, schedule: shedule, monthlyFee: monthly_fee);

    //UI
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Batch added successfully"),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );

    _namecontroller.clear();
    _subjectcontroller.clear();
    _shedulecontroller.clear();
    _monthly_feesController.clear();

  }

  //UI with backend components
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add Batch"),),
      body: Padding(padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _namecontroller,
              decoration: const InputDecoration(labelText: "Batch Name"),
            ),

            const SizedBox(height: 16,),

            TextField(
              controller: _subjectcontroller,
              decoration: const InputDecoration(labelText: "Subject"),
            ),

            const SizedBox(height: 16,),

            TextField(
              controller: _shedulecontroller,
              decoration: const InputDecoration(labelText: "Shedule (eg: Mon-Wed-Fri | 5:00 PM - 6:00 PM)"),
            ),

            const SizedBox(height: 16,),

            TextField(
              controller: _monthly_feesController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: "Monthly fees",
              ),
            ),

            const SizedBox(height: 24,),

            ElevatedButton(onPressed: _addbatch, child: const Text("Add Batch"),),
          ],
        ),
      ),
      ),
    );
  }
}

//Attendence screen
class AttendanceScreen extends StatefulWidget {
  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {

  //Backend components
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String teacherId = FirebaseAuth.instance.currentUser!.uid;

  final _databasehelper = DatabaseHelper();

  String? selectedBatchId;

  String get today => DateTime.now().toIso8601String().split('T')[0];

  //Backend components
  Future<void> toggleAttendance({ required String studentId, required String batchId, required bool markPresent, }) async {

    final studentRef = _db
        .collection("teachers")
        .doc(teacherId)
        .collection("students")
        .doc(studentId);

    final batchRef = _db
        .collection("teachers")
        .doc(teacherId)
        .collection("batches")
        .doc(batchId);

    final attendanceRef = studentRef
        .collection("attendance")
        .doc(today);

    await _db.runTransaction((transaction) async {
      final batchSnap = await transaction.get(batchRef);
      final attendanceSnap = await transaction.get(attendanceRef);

      final batchData = batchSnap.data() as Map<String, dynamic>?;

      String? lastBatchDate = batchData?["last_attendance_date"];

      bool alreadyMarked = attendanceSnap.exists;

      if (markPresent && !alreadyMarked) {
        // MARK PRESENT

        transaction.set(attendanceRef, {
          "date": today,
          "present": true,
        });

        transaction.update(studentRef, {
          "present_days": FieldValue.increment(1),
        });

        if (lastBatchDate != today) {
          transaction.update(batchRef, {
            "total_days": FieldValue.increment(1),
            "last_attendance_date": today,
          });
        }

      } else if (!markPresent && alreadyMarked) {
        // UNMARK PRESENT

        transaction.delete(attendanceRef);

        transaction.update(studentRef, {
          "present_days": FieldValue.increment(-1),
        });

        // DO NOT decrease total_days
        // A working day remains a working day
      }

    });
  }

  //UI
  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(title: const Text("Attendance")),
      body: Column(
        children: [

          /// BATCH DROPDOWN
          StreamBuilder<QuerySnapshot>(
            stream: _databasehelper.getBatches(),
            builder: (context, snapshot) {

              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                );
              }

              final docs = snapshot.data!.docs;

              if (selectedBatchId != null && !docs.any((d) => d.id == selectedBatchId)) { selectedBatchId = null; }

              return Padding(
                padding: const EdgeInsets.all(12.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10)
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    hint: const Text("Select Batch"),
                    value: selectedBatchId,
                    items: docs.map((doc) {
                      return DropdownMenuItem<String>(
                        value: doc.id,
                        child: Text(doc["name"]),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedBatchId = value;
                      });
                    },
                  ),
                ),
                ),
              );
            },
          ),

          /// STUDENTS LIST
          if (selectedBatchId != null)
            Expanded(
              // Backend
              child: StreamBuilder<QuerySnapshot>(
                stream: _db
                    .collection("teachers")
                    .doc(teacherId)
                    .collection("students")
                    .where("batch_id",
                        isEqualTo: selectedBatchId)
                    .where("is_active",
                        isEqualTo: true)
                    .snapshots(),
                builder: (context, snapshot) {
                //UI
                  if (!snapshot.hasData) {
                    return const Center(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 10),
                              Text("Loading students...")
                            ],
                          ),
                        ));
                  }

                  final students = snapshot.data!.docs;

                  if (students.isEmpty) {
                    return const Center(
                        child: Text("No students"));
                  }

                  return ListView.builder(
                    itemCount: students.length,
                    itemBuilder: (context, index) {

                      final doc = students[index];
                      final studentId = doc.id;

                      return StreamBuilder<DocumentSnapshot>(
                        //Backend
                        stream: _db
                            .collection("teachers")
                            .doc(teacherId)
                            .collection("students")
                            .doc(studentId)
                            .collection("attendance")
                            .doc(today)
                            .snapshots(),
                        builder: (context, attSnap) {

                          bool marked = attSnap.data?.exists ?? false;
                          //UI
                          return Container(
                            margin: EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 4,
                                )
                              ],
                            ),
                            child: CheckboxListTile(
                              title: Text(doc["name"]),
                              value: marked,
                              onChanged: (val) {
                                toggleAttendance(
                                  studentId: studentId,
                                  batchId: selectedBatchId!,
                                  markPresent: val!,
                                );
                              },
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

//Payment Screen
class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {

  //Backend components
  final DatabaseHelper _dbHelper = DatabaseHelper();

  String? selectedBatchId;
  double monthlyFee = 0;

  //UI
  void _showPaymentDialog(String studentId, String name) {

    final amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Add Payment - $name"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [

              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: "Amount"),
              ),
            ],
          ),
          actions: [

            TextButton(
              child: const Text("Cancel"),
              onPressed: () => Navigator.pop(context),
            ),

            ElevatedButton(
              child: const Text("Confirm"),
              onPressed: () async {

                final amount =
                    double.tryParse(amountController.text) ?? 0;

                if (amount <= 0) return;

                await _dbHelper.addPayment(
                  studentId: studentId,
                  amount: amount,

                );

                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }
  //UI
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [

        /// BATCH DROPDOWN
        StreamBuilder<QuerySnapshot>(
          stream: _dbHelper.getBatches(),
          builder: (context, snapshot) {

            if (!snapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              );
            }

            final docs = snapshot.data!.docs;

            if (selectedBatchId != null &&
                !docs.any((d) => d.id == selectedBatchId)) {
              selectedBatchId = null;
            }

            return Padding(
              padding: const EdgeInsets.all(12),
              child: DropdownButtonFormField<String>(
                value: selectedBatchId,
                hint: const Text("Select Batch"),
                isExpanded: true,
                items: docs.map((doc) {
                  return DropdownMenuItem<String>(
                    value: doc.id,
                    child: Text(doc["name"]),
                  );
                }).toList(),
                onChanged: (val) async {
                  setState(() {
                    selectedBatchId = val;
                  });

                  if (val != null) {
                    //Backend
                    final batchDoc = await FirebaseFirestore.instance
                        .collection("teachers")
                        .doc(_dbHelper.teacherId)
                        .collection("batches")
                        .doc(val)
                        .get();

                    monthlyFee = batchDoc["monthly_fee"];
                    setState(() {});
                  }
                },
              ),
            );
          },
        ),

        /// STUDENT LIST
        if (selectedBatchId != null)
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              //BAckend
              stream: FirebaseFirestore.instance
                  .collection("teachers")
                  .doc(_dbHelper.teacherId)
                  .collection("students")
                  .where("batch_id", isEqualTo: selectedBatchId)
                  .where("is_active", isEqualTo: true)
                  .snapshots(),
              builder: (context, snapshot) {
                
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final students = snapshot.data!.docs;

                if (students.isEmpty) {
                  return const Center(child: Text("No students"));
                }
                //UI
                return ListView.builder(
                  itemCount: students.length,
                  itemBuilder: (context, index) {

                    final doc = students[index];
                    final studentId = doc.id;
                    final name = doc["name"];
                    final paid = doc["fees_paid"] ?? 0.0;
                    final due = monthlyFee - paid;

                    return Container(
                      margin: const EdgeInsets.symmetric(
                          vertical: 6, horizontal: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: due > 0
                            ? Colors.red.shade50
                            : Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [

                          Text(name,
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold)),

                          const SizedBox(height: 6),

                          Text("Fee: ₹$monthlyFee"),
                          Text("Paid: ₹$paid"),
                          Text("Due: ₹$due"),

                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              child: const Text("Add Payment"),
                              onPressed: () {
                                _showPaymentDialog(
                                  studentId,
                                  name,
                                );
                              },
                            ),
                          )
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          )
      ],
    );
  }
}

class profile extends StatefulWidget {
  const profile({super.key});

  @override
  State<profile> createState() => _profileState();
}

//UI
class _profileState extends State<profile> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Profile Section"),
      ),
      
    );
  }
}