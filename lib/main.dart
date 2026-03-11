// main.dart

// ── Imports ───────────────────────────────────────────────────
import 'Backend/database_helper.dart';
import 'Backend/AuthManager.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ════════════════════════════════════════════════════════════════
// APP COLORS — single source of truth for the entire color palette.
// To retheme the app, only change values here.
// ════════════════════════════════════════════════════════════════
class AppColors {
  AppColors._(); // prevent instantiation

  // ── Backgrounds ──────────────────────────────────────────────
  static const background = Color(0xFFF5F5F5); // main scaffold background
  static const card       = Color(0xFFE0E0E0); // card / secondary background

  // ── Primary ──────────────────────────────────────────────────
  static const primary    = Color(0xFF4A90E2); // buttons, headers, active elements

  // ── Accent ───────────────────────────────────────────────────
  static const success    = Color(0xFF7ED321); // success / paid / present
  static const warning    = Color(0xFFF5A623); // warnings / pending

  // ── Text ─────────────────────────────────────────────────────
  static const textPrimary   = Color(0xFF333333); // main readable text
  static const textSecondary = Color(0xFF666666); // hints, subtitles

  // ── Optional Highlights ───────────────────────────────────────
  static const lavender = Color(0xFFB39DDB); // soft accent for decorations
  static const teal     = Color(0xFF4DB6AC); // soft teal for decorations

  // ── Semantic Aliases (use these in code, not raw values above)─
  static const appBar        = primary;          // app bar background
  static const appBarText    = Colors.white;     // app bar title / icons
  static const buttonBg      = primary;          // elevated button fill
  static const buttonText    = Colors.white;     // elevated button label
  static const error         = Color(0xFFE53935); // errors / dues / absent
  static const divider       = Color(0xFFBDBDBD); // borders, separators
  static const white         = Colors.white;     // explicit white surfaces
}

// ── Entry Point ───────────────────────────────────────────────
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const CoachFlowApp());
}

// ── Root App + Global Theme ───────────────────────────────────
class CoachFlowApp extends StatelessWidget {
  const CoachFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          background: AppColors.background,
          primary: AppColors.primary,
        ),

        // UI: global AppBar — this is the ONE app bar style for the whole app.
        // Push-screens inherit it automatically; no per-screen AppBar needed.
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.appBar,
          foregroundColor: AppColors.appBarText,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: AppColors.appBarText,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          iconTheme: IconThemeData(color: AppColors.appBarText),
        ),

        // UI: global text field style
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.white,
          labelStyle: const TextStyle(color: AppColors.textSecondary),
          floatingLabelStyle: const TextStyle(color: AppColors.primary),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.divider),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),

        // UI: global elevated button style
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.buttonBg,
            foregroundColor: AppColors.buttonText,
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            elevation: 0,
          ),
        ),

        // UI: text button style
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: AppColors.primary),
        ),
      ),

      // Backend: watches Firebase auth state — shows auth or dashboard
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              backgroundColor: AppColors.primary,
              body: Center(child: CircularProgressIndicator(color: AppColors.white)),
            );
          }
          if (snapshot.hasData) return const MainDashboard();
          return const AuthScreen();
        },
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// AUTH SCREEN — login and registration
// ════════════════════════════════════════════════════════════════
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  // Backend: tracks which form is shown
  bool _isLogin   = true;
  bool _isLoading = false;

  // Backend: form field controllers
  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController     = TextEditingController();
  final AuthServices _authServices = AuthServices();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  // Backend: handles sign-in or registration via AuthServices
  Future<void> _submit() async {
    final email    = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name     = _nameController.text.trim();

    if (email.isEmpty || password.isEmpty || (!_isLogin && name.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("All fields are required")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_isLogin) {
        await _authServices.signIn(email: email, password: password);
      } else {
        await _authServices.signUp(name: name, email: email, password: password);
      }
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? "Authentication failed")),
      );
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Something went wrong. Please try again.")),
      );
    }

    if (mounted) setState(() => _isLoading = false);
  }

  // UI: auth screen — no AppBar (branding header built manually)
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // UI: branded top section
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 52, 32, 36),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 52, height: 52,
                      decoration: BoxDecoration(
                        color: AppColors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.school_rounded, color: AppColors.white, size: 28),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      _isLogin ? "Welcome\nback 👋" : "Create\naccount",
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isLogin ? "Sign in to manage your classes" : "Register to get started",
                      style: TextStyle(color: AppColors.white.withOpacity(0.75), fontSize: 15),
                    ),
                  ],
                ),
              ),

              // UI: white form card sliding up from the bottom
              Container(
                width: double.infinity,
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height * 0.58,
                ),
                decoration: const BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(32),
                    topRight: Radius.circular(32),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(28, 36, 28, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // UI: extra name field for registration only
                    if (!_isLogin) ...[
                      TextField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: "Full Name",
                          prefixIcon: Icon(Icons.person_outline, color: AppColors.primary),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: "Email",
                        prefixIcon: Icon(Icons.email_outlined, color: AppColors.primary),
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: "Password",
                        prefixIcon: Icon(Icons.lock_outline, color: AppColors.primary),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // UI: action button or loading spinner
                    _isLoading
                        ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                        : ElevatedButton(
                            onPressed: _submit,
                            child: Text(_isLogin ? "Sign In" : "Create Account"),
                          ),

                    const SizedBox(height: 14),

                    // UI: toggle between login and register
                    Center(
                      child: TextButton(
                        onPressed: () => setState(() => _isLogin = !_isLogin),
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                            children: [
                              TextSpan(
                                text: _isLogin
                                    ? "Don't have an account? "
                                    : "Already have an account? ",
                              ),
                              TextSpan(
                                text: _isLogin ? "Register" : "Login",
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// MAIN DASHBOARD SHELL — single AppBar + bottom nav + page stack
// All inner screens (DashboardScreen, AttendanceScreen, etc.) are
// plain widgets with NO Scaffold/AppBar of their own. The one AppBar
// here is the only AppBar in the entire bottom-nav flow.
// Push-navigated screens (BatchStudentsScreen, AddStudents, etc.)
// get their own Scaffold because they sit outside this shell.
// ════════════════════════════════════════════════════════════════
class MainDashboard extends StatefulWidget {
  const MainDashboard({Key? key}) : super(key: key);
  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  // Backend: active tab index
  int _currentIndex = 0;

  // Backend: tab titles shown in the single AppBar
  static const _titles = ["Dashboard", "Attendance", "Fees", "Profile"];

  // Backend: page widgets — plain, no Scaffold
  final List<Widget> _pages = [
    DashboardScreen(),
    AttendanceScreen(),
    PaymentScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    // UI: ONE Scaffold with ONE AppBar for the entire bottom-nav shell
    return Scaffold(
      backgroundColor: AppColors.background,

      // UI: single AppBar — title changes with the selected tab
      appBar: AppBar(
        title: Text(_titles[_currentIndex]),
        actions: [
          // UI: add-batch action only on Dashboard tab
          if (_currentIndex == 0)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: IconButton(
                tooltip: "Add Batch",
                icon: const Icon(Icons.add),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.white.withOpacity(0.15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddBatch()),
                ),
              ),
            ),
        ],
      ),

      // Backend: IndexedStack keeps page state alive when switching tabs
      body: IndexedStack(index: _currentIndex, children: _pages),

      // UI: FAB for adding a student — only shown on Dashboard tab
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.white,
              elevation: 2,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddStudents()),
              ),
              icon: const Icon(Icons.person_add),
              label: const Text("Add Student", style: TextStyle(fontWeight: FontWeight.bold)),
            )
          : null,

      // UI: bottom navigation bar
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: AppColors.white,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        unselectedLabelStyle: const TextStyle(fontSize: 12),
        elevation: 8,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: "Dashboard",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.check_circle_outline),
            activeIcon: Icon(Icons.check_circle),
            label: "Attendance",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet_outlined),
            activeIcon: Icon(Icons.account_balance_wallet),
            label: "Fees",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: "Profile",
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// DASHBOARD SCREEN — stats grid + batch list (no Scaffold/AppBar)
// ════════════════════════════════════════════════════════════════
class DashboardScreen extends StatelessWidget {
  DashboardScreen({super.key});

  // Backend: teacher UID from Firebase Auth
  final String teacherId = FirebaseAuth.instance.currentUser!.uid;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // UI: greeting banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text("Good day, Teacher!",
                          style: TextStyle(color: AppColors.white, fontSize: 13,
                              fontWeight: FontWeight.w500)),
                      SizedBox(height: 2),
                      Text("Here's your overview",
                          style: TextStyle(color: AppColors.white, fontSize: 20,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                // UI: teal accent decoration icon
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.school_rounded, color: AppColors.white, size: 26),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          const Text("Quick Stats",
              style: TextStyle(color: AppColors.textPrimary, fontSize: 15,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),

          // UI: 2x2 stats grid
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.2,
            children: [
              _buildActiveStudentsCard(),
              _buildBatchesCard(),
              _buildCollectedCard(),
              _buildPendingStudentsCard(),
            ],
          ),

          const SizedBox(height: 24),
          const Text("My Batches",
              style: TextStyle(color: AppColors.textPrimary, fontSize: 15,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),

          // UI + Backend: live batch list
          _buildBatchList(context),
        ],
      ),
    );
  }

  // ── Batch List ────────────────────────────────────────────────
  // Backend: real-time stream of all batches for this teacher
  Widget _buildBatchList(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("teachers")
          .doc(teacherId)
          .collection("batches")
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        }

        final batches = snapshot.data!.docs;

        // UI: empty state
        if (batches.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.divider),
            ),
            child: Column(
              children: [
                Icon(Icons.class_outlined, color: AppColors.lavender, size: 42),
                const SizedBox(height: 10),
                const Text("No batches yet",
                    style: TextStyle(color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text("Tap + in the top-right to create a batch",
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              ],
            ),
          );
        }

        // UI: list of batch cards
        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: batches.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final doc  = batches[index];
            final data = doc.data() as Map<String, dynamic>;

            return _BatchCard(
              batchId:    doc.id,
              name:       data["name"]        ?? "Unnamed",
              subject:    data["subject"]     ?? "",
              schedule:   data["schedule"]    ?? "",
              monthlyFee: (data["monthly_fee"] ?? 0).toStringAsFixed(0),
            );
          },
        );
      },
    );
  }

  // ── Stat Cards ────────────────────────────────────────────────

  // Backend: counts active students
  Widget _buildActiveStudentsCard() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("teachers").doc(teacherId)
          .collection("students")
          .where("is_active", isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) => _statCard(
        title: "Students",
        value: (snapshot.data?.docs.length ?? 0).toString(),
        icon: Icons.people_alt_rounded,
        accent: AppColors.primary,
      ),
    );
  }

  // Backend: counts total batches
  Widget _buildBatchesCard() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("teachers").doc(teacherId)
          .collection("batches")
          .snapshots(),
      builder: (context, snapshot) => _statCard(
        title: "Batches",
        value: (snapshot.data?.docs.length ?? 0).toString(),
        icon: Icons.class_rounded,
        accent: AppColors.teal,
      ),
    );
  }

  // Backend: sums all payment amounts
  Widget _buildCollectedCard() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("teachers").doc(teacherId)
          .collection("payments")
          .snapshots(),
      builder: (context, snapshot) {
        double total = 0;
        if (snapshot.hasData) {
          for (var d in snapshot.data!.docs) total += (d["amount"] ?? 0);
        }
        return _statCard(
          title: "Collected",
          value: "₹${total.toStringAsFixed(0)}",
          icon: Icons.account_balance_wallet_rounded,
          accent: AppColors.success,
        );
      },
    );
  }

  // Backend: counts students who have paid nothing
  Widget _buildPendingStudentsCard() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("teachers").doc(teacherId)
          .collection("students")
          .where("is_active", isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        int pending = 0;
        if (snapshot.hasData) {
          for (var d in snapshot.data!.docs) {
            if ((d["fees_paid"] ?? 0) <= 0) pending++;
          }
        }
        return _statCard(
          title: "Pending Fees",
          value: pending.toString(),
          icon: Icons.warning_amber_rounded,
          accent: AppColors.warning,
        );
      },
    );
  }

  // UI: reusable stat card
  Widget _statCard({
    required String title,
    required String value,
    required IconData icon,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accent, size: 20),
          ),
          const SizedBox(height: 10),
          Text(value,
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold, color: accent)),
          const SizedBox(height: 2),
          Text(title,
              style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// BATCH CARD — tappable row in the dashboard batch list
// ════════════════════════════════════════════════════════════════
class _BatchCard extends StatelessWidget {
  final String batchId, name, subject, schedule, monthlyFee;

  const _BatchCard({
    required this.batchId,
    required this.name,
    required this.subject,
    required this.schedule,
    required this.monthlyFee,
  });

  @override
  Widget build(BuildContext context) {
    // UI: tap navigates to the batch's student list
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BatchStudentsScreen(
            batchId:    batchId,
            batchName:  name,
            monthlyFee: double.tryParse(monthlyFee) ?? 0,
          ),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 6,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            // UI: batch icon with teal accent
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                color: AppColors.teal.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.class_rounded, color: AppColors.teal, size: 22),
            ),
            const SizedBox(width: 14),

            // UI: name, subject, schedule text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary)),
                  if (subject.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(subject,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                  ],
                  if (schedule.isNotEmpty) ...[
                    const SizedBox(height: 1),
                    Text(schedule,
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textSecondary)),
                  ],
                ],
              ),
            ),

            // UI: monthly fee badge + chevron
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text("₹$monthlyFee/mo",
                      style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: 6),
                const Icon(Icons.chevron_right,
                    color: AppColors.textSecondary, size: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// BATCH STUDENTS SCREEN — student list for one batch (has Scaffold)
// ════════════════════════════════════════════════════════════════
class BatchStudentsScreen extends StatelessWidget {
  final String batchId;
  final String batchName;
  final double monthlyFee;

  const BatchStudentsScreen({
    super.key,
    required this.batchId,
    required this.batchName,
    required this.monthlyFee,
  });

  @override
  Widget build(BuildContext context) {
    // Backend: teacher UID
    final teacherId = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(batchName),
        actions: [
          // UI: quick-add student with this batch pre-selected
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton(
              tooltip: "Add Student",
              icon: const Icon(Icons.person_add),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.white.withOpacity(0.15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => AddStudents(preselectedBatchId: batchId)),
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Backend: active students in this specific batch
        stream: FirebaseFirestore.instance
            .collection("teachers")
            .doc(teacherId)
            .collection("students")
            .where("batch_id", isEqualTo: batchId)
            .where("is_active", isEqualTo: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.primary));
          }

          final students = snapshot.data!.docs;

          // UI: empty state
          if (students.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.person_off_outlined,
                        color: AppColors.lavender, size: 52),
                    const SizedBox(height: 16),
                    const Text("No students in this batch",
                        style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    const Text("Tap the button below to add one",
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 13)),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                AddStudents(preselectedBatchId: batchId)),
                      ),
                      icon: const Icon(Icons.person_add),
                      label: const Text("Add Student"),
                      style: ElevatedButton.styleFrom(
                          minimumSize: const Size(200, 48)),
                    ),
                  ],
                ),
              ),
            );
          }

          // UI: student list
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: students.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final doc    = students[index];
              final data   = doc.data() as Map<String, dynamic>;
              final paid   = (data["fees_paid"] ?? 0.0).toDouble();
              final due    = monthlyFee - paid;
              final hasDue = due > 0;

              // UI: tappable student card → StudentCardScreen
              return GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => StudentCardScreen(
                      studentId:   doc.id,
                      studentData: data,
                      monthlyFee:  monthlyFee,
                      batchName:   batchName,
                    ),
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: hasDue
                          ? AppColors.warning.withOpacity(0.5)
                          : AppColors.success.withOpacity(0.5),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 6,
                          offset: const Offset(0, 2))
                    ],
                  ),
                  child: Row(
                    children: [
                      // UI: avatar circle with first letter
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: AppColors.primary.withOpacity(0.12),
                        child: Text(
                          (data["name"] ?? "?")[0].toUpperCase(),
                          style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 16),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // UI: name + fee chips
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(data["name"] ?? "Unknown",
                                style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary)),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                _chip("Paid ₹$paid", AppColors.success),
                                const SizedBox(width: 6),
                                if (hasDue)
                                  _chip("Due ₹$due", AppColors.warning),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right,
                          color: AppColors.textSecondary),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // UI: small colored pill chip
  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(6)),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// STUDENT CARD SCREEN — full detail view for one student
// ════════════════════════════════════════════════════════════════
class StudentCardScreen extends StatelessWidget {
  final String studentId;
  final Map<String, dynamic> studentData;
  final double monthlyFee;
  final String batchName;

  const StudentCardScreen({
    super.key,
    required this.studentId,
    required this.studentData,
    required this.monthlyFee,
    required this.batchName,
  });

  @override
  Widget build(BuildContext context) {
    // Backend: db helper for adding payment
    final db = DatabaseHelper();

    // Backend: parse student data with safe fallbacks
    final name        = studentData["name"]         ?? "Unknown";
    final parentEmail = studentData["parent_email"] ?? "—";
    final parentPhone = studentData["parent_phone"] ?? "—";
    final rollNo      = studentData["roll_no"]      ?? "—";
    final paid        = (studentData["fees_paid"]   ?? 0.0).toDouble();
    final presentDays = studentData["present_days"] ?? 0;
    final due         = monthlyFee - paid;
    final hasDue      = due > 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(name)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // UI: student identity header card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  // UI: lavender-tinted avatar
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: AppColors.white.withOpacity(0.22),
                    child: Text(
                      name[0].toUpperCase(),
                      style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(name,
                      style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(batchName,
                      style: TextStyle(
                          color: AppColors.white.withOpacity(0.75),
                          fontSize: 13)),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // UI: fee summary — paid and due tiles side by side
            Row(
              children: [
                Expanded(
                    child: _statTile(
                        "Paid", "₹$paid", AppColors.success)),
                const SizedBox(width: 12),
                Expanded(
                    child: _statTile(
                        "Due",
                        "₹$due",
                        hasDue ? AppColors.warning : AppColors.success)),
              ],
            ),

            const SizedBox(height: 12),

            // UI: attendance count tile
            _statTile("Days Present", "$presentDays days", AppColors.teal),

            const SizedBox(height: 16),

            // UI: contact and metadata info tiles
            _infoTile(Icons.tag,             "Roll No",       rollNo),
            const SizedBox(height: 10),
            _infoTile(Icons.email_outlined,   "Parent Email",  parentEmail),
            const SizedBox(height: 10),
            _infoTile(Icons.phone_outlined,   "Parent Phone",  parentPhone),
            const SizedBox(height: 10),
            _infoTile(Icons.currency_rupee,   "Monthly Fee",   "₹$monthlyFee"),

            const SizedBox(height: 24),

            // UI: payment button
            ElevatedButton.icon(
              onPressed: () => _showPaymentDialog(context, db),
              icon: const Icon(Icons.add_card),
              label: const Text("Add Payment"),
            ),
          ],
        ),
      ),
    );
  }

  // UI: payment amount dialog
  void _showPaymentDialog(BuildContext context, DatabaseHelper db) {
    final amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Add Payment",
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold)),
            Text(studentData["name"] ?? "",
                style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.normal)),
          ],
        ),
        content: TextField(
          controller: amountController,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: "Amount",
            prefixIcon: Icon(Icons.currency_rupee, color: AppColors.primary),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(100, 44),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final amount = double.tryParse(amountController.text) ?? 0;
              if (amount <= 0) return;
              // Backend: addPayment saves to payments collection + updates student fees_paid
              await db.addPayment(studentId: studentId, amount: amount);
              Navigator.pop(ctx);
            },
            child: const Text("Confirm"),
          ),
        ],
      ),
    );
  }

  // UI: wide stat tile (paid / due / attendance)
  Widget _statTile(String label, String value, Color accent) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold, color: accent)),
        ],
      ),
    );
  }

  // UI: icon + label + value info row tile
  Widget _infoTile(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 4,
              offset: const Offset(0, 1))
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primary, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary)),
                Text(value,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// ADD STUDENTS SCREEN — form to add a new student
// ════════════════════════════════════════════════════════════════
class AddStudents extends StatefulWidget {
  // Optional: pre-selects batch when opened from BatchStudentsScreen
  final String? preselectedBatchId;
  const AddStudents({super.key, this.preselectedBatchId});

  @override
  State<AddStudents> createState() => _AddStudentsState();
}

class _AddStudentsState extends State<AddStudents> {
  // Backend: form controllers
  final _nameController         = TextEditingController();
  final _parentsEmailController = TextEditingController();
  final _parentPhoneController  = TextEditingController();
  final _feesController         = TextEditingController();
  final _rollnocontroller       = TextEditingController();

  final _db = DatabaseHelper();
  String? selectedBatchId;

  @override
  void initState() {
    super.initState();
    // Backend: use pre-selected batch if passed in
    selectedBatchId = widget.preselectedBatchId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _parentsEmailController.dispose();
    _parentPhoneController.dispose();
    _feesController.dispose();
    _rollnocontroller.dispose();
    super.dispose();
  }

  // Backend: validates inputs and saves student to Firestore
  void _addStudent() async {
    final name        = _nameController.text.trim();
    final parentEmail = _parentsEmailController.text.trim();
    final parentPhone = _parentPhoneController.text.trim();
    final feesDue     = double.tryParse(_feesController.text.trim());
    final rollno      = _rollnocontroller.text.trim();

    if (name.isEmpty || parentEmail.isEmpty || parentPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Name, email and phone are required")),
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
        const SnackBar(content: Text("Enter a valid fee amount")),
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

    // UI: success feedback
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Student added successfully"),
        backgroundColor: AppColors.success,
        duration: Duration(seconds: 2),
      ),
    );

    // Backend: clear fields after save
    _nameController.clear();
    _parentPhoneController.clear();
    _parentsEmailController.clear();
    _feesController.clear();
    _rollnocontroller.clear();

    // Keep batch selection only when it was pre-filled
    if (widget.preselectedBatchId == null) {
      setState(() => selectedBatchId = null);
    }
  }

  // UI: add student form
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text("Add Student")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text("Student Details",
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 16),

            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: "Student Name",
                prefixIcon: Icon(Icons.person_outline, color: AppColors.primary),
              ),
            ),
            const SizedBox(height: 14),

            TextField(
              controller: _parentsEmailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: "Parent's Email",
                prefixIcon: Icon(Icons.email_outlined, color: AppColors.primary),
              ),
            ),
            const SizedBox(height: 14),

            TextField(
              controller: _parentPhoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: "Parent's Phone",
                prefixIcon:
                    Icon(Icons.phone_outlined, color: AppColors.primary),
              ),
            ),
            const SizedBox(height: 14),

            TextField(
              controller: _feesController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: "Fees Due",
                prefixIcon:
                    Icon(Icons.currency_rupee, color: AppColors.primary),
              ),
            ),
            const SizedBox(height: 14),

            // Backend: live batch dropdown from Firestore
            StreamBuilder<QuerySnapshot>(
              stream: _db.getBatches(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primary));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  // UI: guide the teacher to create a batch first
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: AppColors.warning.withOpacity(0.4)),
                    ),
                    child: const Text(
                      "No batches found. Create a batch first from the Dashboard.",
                      style: TextStyle(
                          color: AppColors.textPrimary, fontSize: 13),
                    ),
                  );
                }

                // UI: batch picker dropdown
                return DropdownButtonFormField<String>(
                  value: selectedBatchId,
                  decoration: const InputDecoration(
                    labelText: "Select Batch",
                    prefixIcon: Icon(Icons.class_outlined,
                        color: AppColors.primary),
                  ),
                  dropdownColor: AppColors.background,
                  items: snapshot.data!.docs.map((batch) {
                    return DropdownMenuItem<String>(
                      value: batch.id,
                      child: Text(batch["name"]),
                    );
                  }).toList(),
                  onChanged: (value) =>
                      setState(() => selectedBatchId = value),
                );
              },
            ),
            const SizedBox(height: 14),

            TextField(
              controller: _rollnocontroller,
              decoration: const InputDecoration(
                labelText: "Roll No (Optional)",
                prefixIcon: Icon(Icons.tag, color: AppColors.primary),
              ),
            ),
            const SizedBox(height: 28),

            ElevatedButton.icon(
              onPressed: _addStudent,
              icon: const Icon(Icons.person_add),
              label: const Text("Add Student"),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// ADD BATCH SCREEN — form to create a new batch
// ════════════════════════════════════════════════════════════════
class AddBatch extends StatefulWidget {
  const AddBatch({super.key});
  @override
  State<AddBatch> createState() => _AddBatchState();
}

class _AddBatchState extends State<AddBatch> {
  // Backend: form controllers
  final _namecontroller         = TextEditingController();
  final _subjectcontroller      = TextEditingController();
  final _shedulecontroller      = TextEditingController();
  final _monthly_feesController = TextEditingController();
  final _db                     = DatabaseHelper();

  @override
  void dispose() {
    _namecontroller.dispose();
    _subjectcontroller.dispose();
    _shedulecontroller.dispose();
    _monthly_feesController.dispose();
    super.dispose();
  }

  // Backend: validates inputs and saves batch to Firestore
  void _addbatch() {
    final name        = _namecontroller.text.trim();
    final subject     = _subjectcontroller.text.trim();
    final shedule     = _shedulecontroller.text.trim();
    final monthly_fee = double.tryParse(_monthly_feesController.text.trim());

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Batch name is required")),
      );
      return;
    }

    if (monthly_fee == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter a valid monthly fee")),
      );
      return;
    }

    _db.addBatch(
        name: name,
        subject: subject,
        schedule: shedule,
        monthlyFee: monthly_fee);

    // UI: success snackbar + reset fields
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Batch added successfully"),
        backgroundColor: AppColors.success,
        duration: Duration(seconds: 2),
      ),
    );

    _namecontroller.clear();
    _subjectcontroller.clear();
    _shedulecontroller.clear();
    _monthly_feesController.clear();
  }

  // UI: add batch form
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text("Add Batch")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text("Batch Details",
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 16),

            TextField(
              controller: _namecontroller,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: "Batch Name",
                prefixIcon:
                    Icon(Icons.class_outlined, color: AppColors.primary),
              ),
            ),
            const SizedBox(height: 14),

            TextField(
              controller: _subjectcontroller,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: "Subject",
                prefixIcon:
                    Icon(Icons.menu_book_outlined, color: AppColors.primary),
              ),
            ),
            const SizedBox(height: 14),

            TextField(
              controller: _shedulecontroller,
              decoration: const InputDecoration(
                labelText: "Schedule  (e.g. Mon-Wed-Fri | 5 PM)",
                prefixIcon:
                    Icon(Icons.schedule_outlined, color: AppColors.primary),
              ),
            ),
            const SizedBox(height: 14),

            TextField(
              controller: _monthly_feesController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: "Monthly Fees",
                prefixIcon:
                    Icon(Icons.currency_rupee, color: AppColors.primary),
              ),
            ),
            const SizedBox(height: 28),

            ElevatedButton.icon(
              onPressed: _addbatch,
              icon: const Icon(Icons.add_circle_outline),
              label: const Text("Add Batch"),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// ATTENDANCE SCREEN — daily attendance per batch (no Scaffold)
// ════════════════════════════════════════════════════════════════
class AttendanceScreen extends StatefulWidget {
  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  // Backend: Firestore + teacher ID
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String teacherId      = FirebaseAuth.instance.currentUser!.uid;
  final _databasehelper       = DatabaseHelper();

  String? selectedBatchId;

  // Backend: today's ISO date used as the attendance doc ID
  String get today => DateTime.now().toIso8601String().split('T')[0];

  // Backend: Firestore transaction — atomically marks or unmarks attendance
  Future<void> toggleAttendance({
    required String studentId,
    required String batchId,
    required bool markPresent,
  }) async {
    final studentRef =
        _db.collection("teachers").doc(teacherId).collection("students").doc(studentId);
    final batchRef =
        _db.collection("teachers").doc(teacherId).collection("batches").doc(batchId);
    final attendanceRef = studentRef.collection("attendance").doc(today);

    await _db.runTransaction((transaction) async {
      final batchSnap      = await transaction.get(batchRef);
      final attendanceSnap = await transaction.get(attendanceRef);
      final batchData      = batchSnap.data() as Map<String, dynamic>?;
      final lastBatchDate  = batchData?["last_attendance_date"];
      final alreadyMarked  = attendanceSnap.exists;

      if (markPresent && !alreadyMarked) {
        // Backend: set attendance doc + increment student present_days
        transaction.set(attendanceRef, {"date": today, "present": true});
        transaction.update(studentRef, {"present_days": FieldValue.increment(1)});
        if (lastBatchDate != today) {
          // Backend: increment total_days only once per day per batch
          transaction.update(batchRef, {
            "total_days": FieldValue.increment(1),
            "last_attendance_date": today,
          });
        }
      } else if (!markPresent && alreadyMarked) {
        // Backend: delete attendance doc + decrement student present_days
        transaction.delete(attendanceRef);
        transaction.update(studentRef, {"present_days": FieldValue.increment(-1)});
        // total_days is NOT decremented — a working day stays counted
      }
    });
  }

  // UI: attendance tab body (no Scaffold — shell provides one)
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // UI: batch selector dropdown
        StreamBuilder<QuerySnapshot>(
          stream: _databasehelper.getBatches(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(color: AppColors.primary),
              );
            }

            final docs = snapshot.data!.docs;
            if (selectedBatchId != null &&
                !docs.any((d) => d.id == selectedBatchId)) {
              selectedBatchId = null;
            }

            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.divider),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    hint: const Text("Select Batch",
                        style: TextStyle(color: AppColors.textSecondary)),
                    value: selectedBatchId,
                    dropdownColor: AppColors.background,
                    icon: const Icon(Icons.keyboard_arrow_down,
                        color: AppColors.primary),
                    items: docs
                        .map((doc) => DropdownMenuItem<String>(
                              value: doc.id,
                              child: Text(doc["name"],
                                  style: const TextStyle(
                                      color: AppColors.textPrimary)),
                            ))
                        .toList(),
                    onChanged: (value) =>
                        setState(() => selectedBatchId = value),
                  ),
                ),
              ),
            );
          },
        ),

        // UI: today date label
        if (selectedBatchId != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                const Icon(Icons.calendar_today,
                    size: 13, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Text("Today: $today",
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),

        // UI + Backend: student list with live per-student attendance state
        if (selectedBatchId != null)
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _db
                  .collection("teachers")
                  .doc(teacherId)
                  .collection("students")
                  .where("batch_id", isEqualTo: selectedBatchId)
                  .where("is_active", isEqualTo: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: AppColors.primary),
                        SizedBox(height: 10),
                        Text("Loading...",
                            style: TextStyle(
                                color: AppColors.textSecondary)),
                      ],
                    ),
                  );
                }

                final students = snapshot.data!.docs;

                if (students.isEmpty) {
                  return const Center(
                    child: Text("No students in this batch",
                        style: TextStyle(color: AppColors.textSecondary)),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  itemCount: students.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final doc       = students[index];
                    final studentId = doc.id;

                    // Backend: per-student attendance stream for today
                    return StreamBuilder<DocumentSnapshot>(
                      stream: _db
                          .collection("teachers")
                          .doc(teacherId)
                          .collection("students")
                          .doc(studentId)
                          .collection("attendance")
                          .doc(today)
                          .snapshots(),
                      builder: (context, attSnap) {
                        final marked = attSnap.data?.exists ?? false;

                        // UI: checkbox tile — highlighted green when present
                        return Container(
                          decoration: BoxDecoration(
                            color: marked
                                ? AppColors.success.withOpacity(0.10)
                                : AppColors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: marked
                                  ? AppColors.success.withOpacity(0.5)
                                  : AppColors.divider,
                              width: 1.5,
                            ),
                          ),
                          child: CheckboxListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 2),
                            title: Text(
                              doc["name"],
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: marked
                                    ? AppColors.success
                                    : AppColors.textPrimary,
                              ),
                            ),
                            subtitle: Text(
                              marked ? "Present ✓" : "Absent",
                              style: TextStyle(
                                fontSize: 12,
                                color: marked
                                    ? AppColors.success
                                    : AppColors.textSecondary,
                              ),
                            ),
                            value: marked,
                            activeColor: AppColors.success,
                            checkColor: AppColors.white,
                            side: BorderSide(
                                color: marked
                                    ? AppColors.success
                                    : AppColors.divider),
                            onChanged: (val) => toggleAttendance(
                              studentId: studentId,
                              batchId: selectedBatchId!,
                              markPresent: val!,
                            ),
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
    );
  }
}

// ════════════════════════════════════════════════════════════════
// PAYMENT SCREEN — record fee payments per batch (no Scaffold)
// ════════════════════════════════════════════════════════════════
class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});
  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  // Backend: db helper + selected batch state
  final DatabaseHelper _dbHelper = DatabaseHelper();
  String? selectedBatchId;
  double monthlyFee = 0;

  // UI: payment entry dialog
  void _showPaymentDialog(String studentId, String name) {
    final amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.background,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Add Payment",
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold)),
            Text(name,
                style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.normal)),
          ],
        ),
        content: TextField(
          controller: amountController,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: "Amount",
            prefixIcon:
                Icon(Icons.currency_rupee, color: AppColors.primary),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(100, 44),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final amount =
                  double.tryParse(amountController.text) ?? 0;
              if (amount <= 0) return;
              // Backend: saves to payments collection + updates student fees_paid
              await _dbHelper.addPayment(
                  studentId: studentId, amount: amount);
              Navigator.pop(ctx);
            },
            child: const Text("Confirm"),
          ),
        ],
      ),
    );
  }

  // UI: fees tab body (no Scaffold — shell provides one)
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // UI: batch selector dropdown
        StreamBuilder<QuerySnapshot>(
          stream: _dbHelper.getBatches(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(color: AppColors.primary),
              );
            }

            final docs = snapshot.data!.docs;
            if (selectedBatchId != null &&
                !docs.any((d) => d.id == selectedBatchId)) {
              selectedBatchId = null;
            }

            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.divider),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    hint: const Text("Select Batch",
                        style:
                            TextStyle(color: AppColors.textSecondary)),
                    value: selectedBatchId,
                    dropdownColor: AppColors.background,
                    icon: const Icon(Icons.keyboard_arrow_down,
                        color: AppColors.primary),
                    items: docs
                        .map((doc) => DropdownMenuItem<String>(
                              value: doc.id,
                              child: Text(doc["name"],
                                  style: const TextStyle(
                                      color: AppColors.textPrimary)),
                            ))
                        .toList(),
                    onChanged: (val) async {
                      setState(() => selectedBatchId = val);
                      if (val != null) {
                        // Backend: fetch the batch's monthly fee
                        final batchDoc = await FirebaseFirestore.instance
                            .collection("teachers")
                            .doc(_dbHelper.teacherId)
                            .collection("batches")
                            .doc(val)
                            .get();
                        monthlyFee =
                            (batchDoc["monthly_fee"] ?? 0).toDouble();
                        setState(() {});
                      }
                    },
                  ),
                ),
              ),
            );
          },
        ),

        // UI + Backend: student payment cards
        if (selectedBatchId != null)
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("teachers")
                  .doc(_dbHelper.teacherId)
                  .collection("students")
                  .where("batch_id", isEqualTo: selectedBatchId)
                  .where("is_active", isEqualTo: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primary));
                }

                final students = snapshot.data!.docs;

                if (students.isEmpty) {
                  return const Center(
                    child: Text("No students in this batch",
                        style: TextStyle(
                            color: AppColors.textSecondary)),
                  );
                }

                return ListView.separated(
                  padding:
                      const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  itemCount: students.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final doc       = students[index];
                    final studentId = doc.id;
                    final name      = doc["name"];
                    final paid      = (doc["fees_paid"] ?? 0.0).toDouble();
                    final due       = monthlyFee - paid;
                    final hasDue    = due > 0;

                    // UI: fee row card
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: hasDue
                              ? AppColors.warning.withOpacity(0.5)
                              : AppColors.success.withOpacity(0.5),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 6,
                              offset: const Offset(0, 2))
                        ],
                      ),
                      child: Row(
                        children: [
                          // UI: status icon
                          Container(
                            width: 42, height: 42,
                            decoration: BoxDecoration(
                              color: (hasDue
                                      ? AppColors.warning
                                      : AppColors.success)
                                  .withOpacity(0.12),
                              borderRadius:
                                  BorderRadius.circular(12),
                            ),
                            child: Icon(
                              hasDue
                                  ? Icons.warning_amber_rounded
                                  : Icons.check_circle_outline,
                              color: hasDue
                                  ? AppColors.warning
                                  : AppColors.success,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),

                          // UI: name + fee chips
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(name,
                                    style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight:
                                            FontWeight.bold,
                                        color: AppColors
                                            .textPrimary)),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    _feeChip("₹$paid paid",
                                        AppColors.success),
                                    const SizedBox(width: 6),
                                    if (hasDue)
                                      _feeChip("₹$due due",
                                          AppColors.warning),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // UI: pay button
                          GestureDetector(
                            onTap: () =>
                                _showPaymentDialog(studentId, name),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius:
                                    BorderRadius.circular(10),
                              ),
                              child: const Text("Pay",
                                  style: TextStyle(
                                      color: AppColors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13)),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
      ],
    );
  }

  // UI: small colored fee chip
  Widget _feeChip(String label, Color color) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(6)),
      child: Text(label,
          style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600)),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// PROFILE SCREEN — teacher profile info (no Scaffold)
// ════════════════════════════════════════════════════════════════
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // UI: profile body (no Scaffold — the shell provides the AppBar)
    return SingleChildScrollView(
      child: Column(
        children: [
          // UI: primary-colored header with avatar
          Container(
            width: double.infinity,
            color: AppColors.primary,
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: AppColors.white.withOpacity(0.5),
                        width: 3),
                  ),
                  child: CircleAvatar(
                    radius: 44,
                    backgroundColor:
                        AppColors.white.withOpacity(0.18),
                    child: const Icon(Icons.person,
                        size: 44, color: AppColors.white),
                  ),
                ),
                const SizedBox(height: 16),
                const Text("User Name",
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.white)),
                const SizedBox(height: 4),
                Text("user@example.com",
                    style: TextStyle(
                        fontSize: 14,
                        color: AppColors.white.withOpacity(0.75))),
              ],
            ),
          ),

          // UI: info tiles
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _profileTile(
                    Icons.school_outlined, "Role", "Teacher"),
                const SizedBox(height: 10),
                _profileTile(Icons.calendar_today_outlined,
                    "Member since", "2024"),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // UI: single info row tile
  Widget _profileTile(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 4,
              offset: const Offset(0, 1))
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary)),
              Text(value,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
            ],
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// NOTE: The old `profile` class has been renamed to `ProfileScreen`
// for consistency. Update any remaining references if needed.
// ════════════════════════════════════════════════════════════════