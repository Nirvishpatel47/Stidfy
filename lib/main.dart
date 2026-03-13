// main.dart — CoachFlow App
// ════════════════════════════════════════════════════════════════
// ARCHITECTURE NOTES (for team):
//  • UI:      All layout/widget/style code is labeled "// UI:"
//  • Backend: All Firestore/Auth/data code is labeled "// Backend:"
//  • The shell (MainDashboard) owns the ONE AppBar for bottom-nav tabs.
//    Push-screens (AddBatch, AddStudents, etc.) have their own Scaffold.
//  • Color changes → AppColors only.
//  • Firestore changes → DatabaseHelper (Backend/database_helper.dart).
// ════════════════════════════════════════════════════════════════

import 'Backend/database_helper.dart';
import 'Backend/AuthManager.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ════════════════════════════════════════════════════════════════
// APP COLORS — single source of truth.
// UI: to retheme the app, only change values here.
// ════════════════════════════════════════════════════════════════
class AppColors {
  AppColors._();

  // UI: backgrounds
  static const background = Color(0xFFF5F5F5);
  static const card       = Color(0xFFFFFFFF);

  // UI: primary brand
  static const primary    = Color(0xFF4A90E2);

  // UI: semantic colors
  static const success    = Color(0xFF43A047);
  static const warning    = Color(0xFFF5A623);
  static const error      = Color(0xFFE53935);

  // UI: text
  static const textPrimary   = Color(0xFF1A1A2E);
  static const textSecondary = Color(0xFF888888);

  // UI: accents
  static const lavender = Color(0xFFB39DDB);
  static const teal     = Color(0xFF26A69A);

  // UI: semantic aliases
  static const appBar      = primary;
  static const appBarText  = Colors.white;
  static const buttonBg    = primary;
  static const buttonText  = Colors.white;
  static const divider     = Color(0xFFE0E0E0);
  static const white       = Colors.white;
}

// ── Entry Point ───────────────────────────────────────────────
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // UI: lock to portrait for consistent layout
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await Firebase.initializeApp();
  runApp(const CoachFlowApp());
}

// ════════════════════════════════════════════════════════════════
// ROOT APP — global theme
// ════════════════════════════════════════════════════════════════
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

        // UI: global AppBar style
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

        // UI: global elevated button
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

        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: AppColors.primary),
        ),
      ),

      // Backend: auth state gate — shows auth or dashboard
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
// AUTH SCREEN — login / register
// ════════════════════════════════════════════════════════════════
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  // Backend: form state
  bool _isLogin   = true;
  bool _isLoading = false;

  // Backend: controllers
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

  // Backend: sign-in or register via AuthServices
  Future<void> _submit() async {
    final email    = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name     = _nameController.text.trim();

    if (email.isEmpty || password.isEmpty || (!_isLogin && name.isEmpty)) {
      _showSnack("All fields are required");
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
      _showSnack(e.message ?? "Authentication failed");
    } catch (_) {
      _showSnack("Something went wrong. Please try again.");
    }
    if (mounted) setState(() => _isLoading = false);
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // UI: branding header
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
                        color: AppColors.white, fontSize: 34,
                        fontWeight: FontWeight.bold, height: 1.2,
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

              // UI: form card
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
                    _isLoading
                        ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                        : ElevatedButton(
                            onPressed: _submit,
                            child: Text(_isLogin ? "Sign In" : "Create Account"),
                          ),
                    const SizedBox(height: 14),
                    Center(
                      child: TextButton(
                        onPressed: () => setState(() => _isLogin = !_isLogin),
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                            children: [
                              TextSpan(
                                text: _isLogin ? "Don't have an account? " : "Already have an account? ",
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
// MAIN DASHBOARD SHELL — one AppBar + bottom nav + page stack
// UI: all inner screens are plain widgets (no Scaffold/AppBar).
//     Push-navigated screens have their own Scaffold.
// ════════════════════════════════════════════════════════════════s
class MainDashboard extends StatefulWidget {
  const MainDashboard({Key? key}) : super(key: key);
  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  int _currentIndex = 0;

  static const _titles = ["Dashboard", "Attendance", "Fees", "Profile"];

  // Backend: Function to switch tabs
  void _changeTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  // UI: Helper to open AddBatch
  void _openAddBatch() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const AddBatch()));
  }

  @override
  Widget build(BuildContext context) {
    // UI: We define the pages inside build so they can access _changeTab correctly
    final List<Widget> pages = [
      DashboardScreen(
        onCreateBatch: _openAddBatch, 
        onNavigate: _changeTab, // Passing the function reference
      ),
      const AttendanceScreen(),
      const PaymentScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_titles[_currentIndex]),
        actions: [
          if (_currentIndex == 3)
            IconButton(
              tooltip: "Sign Out",
              icon: const Icon(Icons.logout),
              onPressed: () => FirebaseAuth.instance.signOut(),
            ),
        ],
      ),
      // Backend: Display the active page
      body: IndexedStack(index: _currentIndex, children: pages),

      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: AppColors.white,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        unselectedLabelStyle: const TextStyle(fontSize: 12),
        elevation: 8,
        onTap: _changeTab, // Directly call the function
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), activeIcon: Icon(Icons.dashboard), label: "Dashboard"),
          BottomNavigationBarItem(icon: Icon(Icons.check_circle_outline), activeIcon: Icon(Icons.check_circle), label: "Attendance"),
          BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet_outlined), activeIcon: Icon(Icons.account_balance_wallet), label: "Fees"),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: "Profile"),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// DASHBOARD SCREEN — analytics + batch list (no Scaffold)
// UI: first screen user sees. Must be immediately actionable.
//     When no batches exist → full-screen onboarding guide.
//     When batches exist → analytics + batch cards with clear CTAs.
// ════════════════════════════════════════════════════════════════
class DashboardScreen extends StatelessWidget {
  final VoidCallback onCreateBatch;
  final Function(int) onNavigate;

  DashboardScreen({
    super.key, 
    required this.onCreateBatch, 
    required this.onNavigate, 
  });

  final String teacherId = FirebaseAuth.instance.currentUser!.uid;

  @override
  Widget build(BuildContext context) {
    // Backend: stream batches to decide which screen state to show
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

        // UI: EMPTY STATE — first-time user onboarding.
        // Psychology: user lands here and immediately knows WHAT to do.
        // Step 1 → Create batch. Step 2 → Add students. Simple sequence.
        if (batches.isEmpty) {
          return _buildOnboardingState(context);
        }

        // UI: main dashboard with analytics + batch list
        return _buildDashboardContent(context, batches);
      },
    );
  }

  // ── Onboarding (empty state) ──────────────────────────────────
  // UI: shown only when teacher has zero batches.
  // Clear step-by-step guide so user is never lost.
  Widget _buildOnboardingState(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          // UI: hero icon Mark
          Container(
            width: 88, height: 88,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.10),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(Icons.school_rounded, color: AppColors.primary, size: 44),
          ),
          const SizedBox(height: 20),
          const Text(
            "Welcome to CoachFlow!",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            "Let's set up your classes in 2 easy steps.",
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 36),

          // UI: Step 1 — Create Batch (PRIMARY action, most prominent)
          _OnboardingStep(
            step: "1",
            icon: Icons.class_rounded,
            color: AppColors.primary,
            title: "Create a Batch",
            subtitle: "e.g. 'Morning Math' or 'Science Std 10'",
            actionLabel: "Create Batch →",
            onTap: onCreateBatch,
            isPrimary: true,
          ),
          const SizedBox(height: 16),

          // UI: Step 2 — Add Students (shown dimmed to signal order)
          _OnboardingStep(
            step: "2",
            icon: Icons.person_add_rounded,
            color: AppColors.teal,
            title: "Add Students",
            subtitle: "After creating a batch, add students to it.",
            actionLabel: "Add Student →",
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddStudents()),
            ),
            isPrimary: false,
          ),
        ],
      ),
    );
  }

  // ── Main Dashboard Content ────────────────────────────────────
  Widget _buildDashboardContent(BuildContext context, List<QueryDocumentSnapshot> batches) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Greeting banner
          _buildGreetingBanner(context),
          const SizedBox(height: 16),

          // 2. Next Action Card — contextual, guides teacher to next step
          _NextActionCard(batches: batches, onCreateBatch: onCreateBatch, onNavigate: onNavigate,),
          const SizedBox(height: 20),

          // 3. Analytics
          const Text("Today's Overview",
              style: TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _buildAnalyticsGrid(),
          const SizedBox(height: 24),

          // 4. My Batches header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("My Batches",
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.bold)),
              GestureDetector(
                onTap: onCreateBatch,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.add, size: 14, color: AppColors.primary),
                      SizedBox(width: 4),
                      Text("New Batch",
                          style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Batch cards — now pass startDate + durationMonths
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: batches.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final doc  = batches[index];
              final data = doc.data() as Map<String, dynamic>;
              return _BatchCard(
                batchId:        doc.id,
                name:           data["name"]             ?? "Unnamed",
                subject:        data["subject"]          ?? "",
                schedule:       data["schedule"]         ?? "",
                monthlyFee:     (data["monthly_fee"]     ?? 0).toStringAsFixed(0),
                startDate:      data["start_date"]       as Timestamp?,   // NEW
                durationMonths: (data["duration_months"] ?? 1) as int,    // NEW
              );
            },
          ),

          const SizedBox(height: 16),

          // 5. Quick Actions
          const Text("Quick Actions",
              style: TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _QuickActionButton(
                  icon: Icons.person_add_rounded,
                  label: "Add Student",
                  color: AppColors.teal,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddStudents())),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _QuickActionButton(
                  icon: Icons.check_circle_outline,
                  label: "Attendance",
                  color: AppColors.success,
                  onTap: () => onNavigate(1), // UI: handled by bottom nav tab switch if needed
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _QuickActionButton(
                  icon: Icons.account_balance_wallet_outlined,
                  label: "Record Payment",
                  color: AppColors.warning,
                  onTap: () => onNavigate(2), // UI: handled by bottom nav
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _QuickActionButton(
                  icon: Icons.add_circle_outline,
                  label: "Create Batch",
                  color: AppColors.primary,
                  onTap: onCreateBatch,
                ),
              ),   
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: _QuickActionButton(
              icon: Icons.quiz_rounded,
              label: "Add Test Marks",
              color: AppColors.lavender,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SelectBatchForTestScreen()),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // UI: greeting banner with date
  Widget _buildGreetingBanner(BuildContext context) {
    final now    = DateTime.now();
    final hour   = now.hour;
    final greeting = hour < 12 ? "Good morning" : hour < 17 ? "Good afternoon" : "Good evening";
    // Backend: get display name from auth
    final displayName = FirebaseAuth.instance.currentUser?.displayName ?? "Teacher";

    return Container(
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
              children: [
                Text("$greeting, $displayName 👋",
                    style: const TextStyle(color: AppColors.white, fontSize: 13, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text(
                  "${now.day} ${_monthName(now.month)} ${now.year}",
                  style: TextStyle(color: AppColors.white.withOpacity(0.85), fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
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
    );
  }

  // UI: helper for month names
  String _monthName(int m) =>
      const ["","Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"][m];

  // ── Analytics Grid ────────────────────────────────────────────
  // UI: 4 cards — data that matters daily.
  Widget _buildAnalyticsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.25,
      children: [
        _buildTodayAttendanceCard(),
        _buildMonthlyDueCard(),
        _buildActiveStudentsCard(),
        _buildCollectedThisMonthCard(),
      ],
    );
  }

  // Backend: students present TODAY (checks attendance subcollection for today's date)
  Widget _buildTodayAttendanceCard() {
    final today = DateTime.now().toIso8601String().split('T')[0];
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("teachers").doc(teacherId).collection("students")
          .where("is_active", isEqualTo: true).snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return _statCard(title: "Today Present",value:  "...",icon:  Icons.how_to_reg_rounded,accent:  AppColors.teal);
        // Backend: count how many students have an attendance doc for today
        // NOTE: This does a client-side count. For large rosters (100+),
        //       consider a Cloud Function that writes a daily summary doc.
        int present = 0;
        for (final doc in snap.data!.docs) {
          // Backend: we use a separate FutureBuilder per student — this fires in parallel
          // and is acceptable for typical class sizes (< 50 students).
        }
        // UI: show total active students as denominator for context
        final total = snap.data!.docs.length;
        return _AttendanceTodayCard(teacherId: teacherId, today: today, total: total);
      },
    );
  }

  // Backend: total fees due this month across all active students
  Widget _buildMonthlyDueCard() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("teachers").doc(teacherId).collection("students")
          .where("is_active", isEqualTo: true).snapshots(),
      builder: (context, snap) {
        double totalDue = 0;
        if (snap.hasData) {
          for (var d in snap.data!.docs) {
            totalDue += (d["fees_due"] ?? 0).toDouble() - (d["fees_paid"] ?? 0).toDouble();
          }
          if (totalDue < 0) totalDue = 0;
        }
        return _statCard(
          title: "Fees Pending",
          value: totalDue > 0 ? "₹${totalDue.toStringAsFixed(0)}" : "₹0",
          icon:  Icons.warning_amber_rounded,
          accent:  totalDue > 0 ? AppColors.warning : AppColors.success,
        );
      },
    );
  }

  // Backend: count active students
  Widget _buildActiveStudentsCard() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("teachers").doc(teacherId).collection("students")
          .where("is_active", isEqualTo: true).snapshots(),
      builder: (context, snap) => _statCard(
        title: "Students",
        value: (snap.data?.docs.length ?? 0).toString(),
        icon: Icons.people_alt_rounded,
        accent: AppColors.primary,
      ),
    );
  }

  // Backend: sum all payments this calendar month
  Widget _buildCollectedThisMonthCard() {
    final now   = DateTime.now();
    final start = Timestamp.fromDate(DateTime(now.year, now.month, 1));
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("teachers").doc(teacherId).collection("payments")
          .where("timestamp", isGreaterThanOrEqualTo: start)
          .snapshots(),
      builder: (context, snap) {
        double total = 0;
        if (snap.hasData) {
          for (var d in snap.data!.docs) total += (d["amount"] ?? 0).toDouble();
        }
        return _statCard(
          title: "This Month",
          value: "₹${total.toStringAsFixed(0)}",
          icon: Icons.account_balance_wallet_rounded,
          accent: AppColors.success,
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
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2)),
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
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: accent)),
          Text(title,
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
  
}

// ── Today Attendance Card ─────────────────────────────────────
// UI: separate StatefulWidget to independently fetch today's attendance count.
// Backend: queries all active students + checks their attendance docs for today.
class _AttendanceTodayCard extends StatefulWidget {
  final String teacherId, today;
  final int total;
  const _AttendanceTodayCard({required this.teacherId, required this.today, required this.total});
  @override
  State<_AttendanceTodayCard> createState() => _AttendanceTodayCardState();
}

class _AttendanceTodayCardState extends State<_AttendanceTodayCard> {
  int _present = 0;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _fetchCount();
  }

  // Backend: get all active student IDs then count today's attendance docs
  Future<void> _fetchCount() async {
    try {
      final students = await FirebaseFirestore.instance
          .collection("teachers").doc(widget.teacherId).collection("students")
          .where("is_active", isEqualTo: true).get();

      int count = 0;
      for (final s in students.docs) {
        final attDoc = await FirebaseFirestore.instance
            .collection("teachers").doc(widget.teacherId)
            .collection("students").doc(s.id)
            .collection("attendance").doc(widget.today).get();
        if (attDoc.exists) count++;
      }
      if (mounted) setState(() { _present = count; _loaded = true; });
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.teal.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.how_to_reg_rounded, color: AppColors.teal, size: 20),
          ),
          const SizedBox(height: 10),
          Text(
            _loaded ? "$_present/${widget.total}" : "...",
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.teal),
          ),
          const Text("Today Present",
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// ── Onboarding Step Card ──────────────────────────────────────
// UI: used in empty-state onboarding sequence.
class _OnboardingStep extends StatelessWidget {
  final String step, title, subtitle, actionLabel;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool isPrimary;

  const _OnboardingStep({
    required this.step,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onTap,
    required this.isPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isPrimary ? color : AppColors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: isPrimary ? color : AppColors.divider, width: isPrimary ? 0 : 1.5),
          boxShadow: isPrimary
              ? [BoxShadow(color: color.withOpacity(0.25), blurRadius: 16, offset: const Offset(0, 6))]
              : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            // UI: step number badge
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: isPrimary ? AppColors.white.withOpacity(0.2) : color.withOpacity(0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(step,
                    style: TextStyle(
                      color: isPrimary ? AppColors.white : color,
                      fontWeight: FontWeight.bold, fontSize: 18,
                    )),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold,
                        color: isPrimary ? AppColors.white : AppColors.textPrimary,
                      )),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: isPrimary ? AppColors.white.withOpacity(0.8) : AppColors.textSecondary,
                      )),
                ],
              ),
            ),
            Text(actionLabel,
                style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.bold,
                  color: isPrimary ? AppColors.white : color,
                )),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// NEXT ACTION CARD — contextual guide shown at top of dashboard
// UI: checks batch + student state to show the most relevant action.
// ════════════════════════════════════════════════════════════════
class _NextActionCard extends StatelessWidget {
  final List<QueryDocumentSnapshot> batches;
  final VoidCallback onCreateBatch;
  final Function(int) onNavigate;

  const _NextActionCard({required this.batches, required this.onCreateBatch, required this.onNavigate,});

  @override
  Widget build(BuildContext context) {
    final teacherId = FirebaseAuth.instance.currentUser!.uid;

    // Backend: check if any student exists across all batches
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("teachers").doc(teacherId)
          .collection("students")
          .where("is_active", isEqualTo: true)
          .limit(1)
          .snapshots(),
      builder: (context, snap) {
        // UI: determine next step contextually
        final hasStudents = (snap.data?.docs.isNotEmpty) ?? false;

        IconData icon;
        String title, subtitle, buttonLabel;
        Color color;
        VoidCallback onTap;

        if (!hasStudents) {
          // No students yet → prompt to add
          icon        = Icons.person_add_rounded;
          title       = "Add students to your batch";
          subtitle    = "Your batch is ready — add the first student now.";
          buttonLabel = "Add Student";
          color       = AppColors.teal;
          onTap       = () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddStudents()));
        } else {
          // Students exist → suggest marking attendance
          icon        = Icons.check_circle_outline;
          title       = "Mark today's attendance";
          subtitle    = "You have active students. Keep attendance up to date.";
          buttonLabel = "Mark Attendance";
          color       = AppColors.success;
          onTap       = () => onNavigate(1); // UI: switch to Attendance tab if wired
        }

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.30)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(buttonLabel,
                      style: const TextStyle(color: AppColors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════
// QUICK ACTION BUTTON — large thumb-friendly button tile
// ════════════════════════════════════════════════════════════════
class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.25)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 1))],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 8),
            Text(label,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// BATCH CARD — tappable card in dashboard batch list
// UI: shows student count (live), fee/mo, and start date.
// ════════════════════════════════════════════════════════════════
class _BatchCard extends StatelessWidget {
  final String batchId, name, subject, schedule, monthlyFee;
  final Timestamp? startDate;       // NEW
  final int durationMonths;         // NEW

  const _BatchCard({
    required this.batchId,
    required this.name,
    required this.subject,
    required this.schedule,
    required this.monthlyFee,
    this.startDate,
    this.durationMonths = 1,
  });

  @override
  Widget build(BuildContext context) {
    // UI: format start date string
    String startStr = "—";
    if (startDate != null) {
      final d = startDate!.toDate();
      const months = ["","Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];
      startStr = "${d.day} ${months[d.month]} ${d.year}";
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          // UI: main tappable area — navigates to student list
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BatchStudentsScreen(
                  batchId: batchId,
                  batchName: name,
                  monthlyFee: double.tryParse(monthlyFee) ?? 0,
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
              child: Row(
                children: [
                  // UI: batch icon
                  Container(
                    width: 46, height: 46,
                    decoration: BoxDecoration(
                      color: AppColors.teal.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.class_rounded, color: AppColors.teal, size: 22),
                  ),
                  const SizedBox(width: 14),

                  // UI: batch info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                        if (subject.isNotEmpty)
                          Text(subject,
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        if (schedule.isNotEmpty)
                          Text(schedule,
                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        const SizedBox(height: 4),
                        // UI: start date + duration chip row
                        Row(
                          children: [
                            const Icon(Icons.calendar_today_outlined, size: 11, color: AppColors.textSecondary),
                            const SizedBox(width: 3),
                            Text("$startStr · $durationMonths mo",
                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // UI: fee badge + live student count
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
                                fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(height: 4),
                      // UI: live student count for this batch
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection("teachers")
                            .doc(FirebaseAuth.instance.currentUser!.uid)
                            .collection("students")
                            .where("batch_id", isEqualTo: batchId)
                            .where("is_active", isEqualTo: true)
                            .snapshots(),
                        builder: (context, snap) {
                          final count = snap.data?.docs.length ?? 0;
                          return Row(
                            children: [
                              const Icon(Icons.people_outline, size: 12, color: AppColors.textSecondary),
                              const SizedBox(width: 3),
                              Text("$count students",
                                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // UI: divider + action bar at bottom of card
          const Divider(height: 1, color: AppColors.divider),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    icon: const Icon(Icons.people, size: 15),
                    label: const Text("View Students", style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BatchStudentsScreen(
                          batchId: batchId,
                          batchName: name,
                          monthlyFee: double.tryParse(monthlyFee) ?? 0,
                        ),
                      ),
                    ),
                  ),
                ),
                Container(width: 1, height: 24, color: AppColors.divider),
                TextButton.icon(
                  icon: const Icon(Icons.edit_outlined, size: 15),
                  label: const Text("Edit", style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EditBatch(
                        batchId: batchId,
                        initialName: name,
                        initialSubject: subject,
                        initialSchedule: schedule,
                        initialMonthlyFee: monthlyFee,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// BATCH STUDENTS SCREEN — student list for one batch
// UI: has its own Scaffold (push screen).
//     Student cards show name, fee status, and edit button.
// ════════════════════════════════════════════════════════════════
class BatchStudentsScreen extends StatelessWidget {
  final String batchId, batchName;
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
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton(
              tooltip: "Add Student to this batch",
              icon: const Icon(Icons.person_add),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.white.withOpacity(0.15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => AddStudents(preselectedBatchId: batchId)),
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Backend: real-time active students in this batch
        stream: FirebaseFirestore.instance
            .collection("teachers").doc(teacherId).collection("students")
            .where("batch_id", isEqualTo: batchId)
            .where("is_active", isEqualTo: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }

          final students = snapshot.data!.docs;

          if (students.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.person_off_outlined, color: AppColors.lavender, size: 52),
                    const SizedBox(height: 16),
                    const Text("No students yet",
                        style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    const Text("Add students to this batch",
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => AddStudents(preselectedBatchId: batchId)),
                      ),
                      icon: const Icon(Icons.person_add),
                      label: const Text("Add Student"),
                      style: ElevatedButton.styleFrom(minimumSize: const Size(200, 48)),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: students.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final doc    = students[index];
              final data   = doc.data() as Map<String, dynamic>;
              final paid   = (data["fees_paid"]  ?? 0.0).toDouble();
              final due    = (data["fees_due"]   ?? monthlyFee).toDouble();
              final hasDue = (due - paid) > 0;

              return _StudentListCard(
                studentId:   doc.id,
                data:        data,
                paid:        paid,
                due:         due,
                hasDue:      hasDue,
                monthlyFee:  monthlyFee,
                batchName:   batchName,
              );
            },
          );
        },
      ),
    );
  }
}

// ── Student List Card ─────────────────────────────────────────
// UI: tappable card with fee status + edit button.
// Backend: reads fees_paid and fees_due from student doc.
class _StudentListCard extends StatelessWidget {
  final String studentId, batchName;
  final Map<String, dynamic> data;
  final double paid, due, monthlyFee;
  final bool hasDue;

  const _StudentListCard({
    required this.studentId,
    required this.data,
    required this.paid,
    required this.due,
    required this.hasDue,
    required this.monthlyFee,
    required this.batchName,
  });

  @override
  Widget build(BuildContext context) {
    final name       = data["name"] ?? "Unknown";
    final remaining  = (due - paid).clamp(0.0, double.infinity);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasDue ? AppColors.warning.withOpacity(0.5) : AppColors.success.withOpacity(0.5),
          width: 1.5,
        ),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          // UI: main tappable area
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => StudentCardScreen(
                  studentId: studentId, studentData: data,
                  monthlyFee: monthlyFee, batchName: batchName,
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
              child: Row(
                children: [
                  // UI: avatar
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: AppColors.primary.withOpacity(0.12),
                    child: Text(
                      name[0].toUpperCase(),
                      style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            _chip("Paid ₹${paid.toStringAsFixed(0)}", AppColors.success),
                            const SizedBox(width: 6),
                            if (hasDue)
                              _chip("Due ₹${remaining.toStringAsFixed(0)}", AppColors.warning),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                ],
              ),
            ),
          ),

          // UI: action bar — Edit student
          const Divider(height: 1, color: AppColors.divider),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: Row(
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.edit_outlined, size: 14),
                  label: const Text("Edit", style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EditStudent(studentId: studentId, initialData: data),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// STUDENT CARD SCREEN — full detail for one student
// ════════════════════════════════════════════════════════════════
class StudentCardScreen extends StatelessWidget {
  final String studentId, batchName;
  final Map<String, dynamic> studentData;
  final double monthlyFee;

  const StudentCardScreen({
    super.key,
    required this.studentId,
    required this.studentData,
    required this.monthlyFee,
    required this.batchName,
  });

  @override
  Widget build(BuildContext context) {
    // Backend: db helper
    final db = DatabaseHelper();

    // Backend: safe data extraction with fallbacks
    final name        = studentData["name"]         ?? "Unknown";
    final parentEmail = studentData["parent_email"] ?? "—";
    final parentPhone = studentData["parent_phone"] ?? "—";
    final rollNo      = studentData["roll_no"]      ?? "—";
    final paid        = (studentData["fees_paid"]   ?? 0.0).toDouble();
    final feesDue     = (studentData["fees_due"]    ?? monthlyFee).toDouble();
    final presentDays = studentData["present_days"] ?? 0;
    final remaining   = (feesDue - paid).clamp(0.0, double.infinity);
    final isFullyPaid = remaining <= 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(name),
        actions: [
          // UI: edit button in AppBar
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: "Edit Student",
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => EditStudent(studentId: studentId, initialData: studentData),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // UI: identity header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: AppColors.white.withOpacity(0.22),
                    child: Text(name[0].toUpperCase(),
                        style: const TextStyle(color: AppColors.white, fontSize: 30, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 12),
                  Text(name,
                      style: const TextStyle(color: AppColors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(batchName,
                      style: TextStyle(color: AppColors.white.withOpacity(0.75), fontSize: 13)),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // UI: fee summary tiles
            Row(
              children: [
                Expanded(child: _statTile("Paid", "₹${paid.toStringAsFixed(0)}", AppColors.success)),
                const SizedBox(width: 12),
                Expanded(child: _statTile("Remaining", "₹${remaining.toStringAsFixed(0)}",
                    isFullyPaid ? AppColors.success : AppColors.warning)),
              ],
            ),
            const SizedBox(height: 12),
            _statTile("Days Present", "$presentDays days", AppColors.teal),
            const SizedBox(height: 16),

            // UI: contact info
            _infoTile(Icons.tag,           "Roll No",      rollNo),
            const SizedBox(height: 10),
            _infoTile(Icons.email_outlined, "Parent Email", parentEmail),
            const SizedBox(height: 10),
            _infoTile(Icons.phone_outlined, "Parent Phone", parentPhone),
            const SizedBox(height: 10),
            _infoTile(Icons.currency_rupee, "Monthly Fee",  "₹$monthlyFee"),

            const SizedBox(height: 24),
            
            _TestMarksSection(studentId: studentId, batchName: batchName),
            
            const SizedBox(height: 24),
            
            // UI: pay full fees button (one tap = done, no manual entry)
            if (!isFullyPaid)
              ElevatedButton.icon(
                onPressed: () => _confirmPayFull(context, db, remaining),
                icon: const Icon(Icons.check_circle_outline),
                label: Text("Mark Full Payment  ₹${remaining.toStringAsFixed(0)}"),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
              ),

            if (isFullyPaid)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.success.withOpacity(0.3)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, color: AppColors.success, size: 20),
                    SizedBox(width: 8),
                    Text("Fees Fully Paid",
                        style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 15)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // UI: confirmation dialog before marking full payment
  void _confirmPayFull(BuildContext context, DatabaseHelper db, double amount) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Confirm Payment",
            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        content: Text(
          "Mark ₹${amount.toStringAsFixed(0)} as paid for ${studentData["name"] ?? ""}?",
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              minimumSize: const Size(100, 44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              // Backend: record full remaining amount as payment
              await db.addPayment(studentId: studentId, amount: amount);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text("Confirm"),
          ),
        ],
      ),
    );
  }

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
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: accent)),
        ],
      ),
    );
  }

  Widget _infoTile(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 1))],
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
                Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                Text(value,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// TEST MARKS SECTION — shown inside StudentCardScreen
// UI: groups tests by subject, shows each test row, computes
//     average percentage and overall grade per subject grouping.
// Backend: reads from students/{sid}/tests subcollection.
// ════════════════════════════════════════════════════════════════
class _TestMarksSection extends StatefulWidget {
  final String studentId, batchName;
  const _TestMarksSection({required this.studentId, required this.batchName});
  @override
  State<_TestMarksSection> createState() => _TestMarksSectionState();
}

class _TestMarksSectionState extends State<_TestMarksSection> {
  final String teacherId = FirebaseAuth.instance.currentUser!.uid;

  // UI: selected date filter — defaults to today's month
  DateTime _selectedDate = DateTime.now();

  String get _selectedDateStr =>
      "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}";

  // UI: grade calculator
  String _grade(double pct) {
    if (pct >= 90) return "A+";
    if (pct >= 80) return "A";
    if (pct >= 70) return "B+";
    if (pct >= 60) return "B";
    if (pct >= 50) return "C";
    if (pct >= 40) return "D";
    return "F";
  }

  Color _gradeColor(double pct) {
    if (pct >= 80) return AppColors.success;
    if (pct >= 60) return AppColors.teal;
    if (pct >= 40) return AppColors.warning;
    return AppColors.error;
  }

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    const months = ["","Jan","Feb","Mar","Apr","May","Jun",
                    "Jul","Aug","Sep","Oct","Nov","Dec"];

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("teachers").doc(teacherId)
          .collection("students").doc(widget.studentId)
          .collection("tests")
          .orderBy("date", descending: false)
          .snapshots(),
      builder: (context, snap) {
        // Section header — always shown
        Widget header = Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Test Marks (${widget.batchName})",
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            // UI: month filter pill
            GestureDetector(
              onTap: _pickMonth,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_month_outlined, size: 13, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text(
                      "${months[_selectedDate.month]} ${_selectedDate.year}",
                      style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600),
                    ),
                    const Icon(Icons.arrow_drop_down, size: 16, color: AppColors.primary),
                  ],
                ),
              ),
            ),
          ],
        );

        if (!snap.hasData) {
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            header,
            const SizedBox(height: 16),
            const Center(child: CircularProgressIndicator(color: AppColors.primary)),
          ]);
        }

        // Filter tests by selected month
        final allTests = snap.data!.docs.where((doc) {
          final date = (doc.data() as Map<String, dynamic>)["date"] as String? ?? "";
          return date.startsWith(_selectedDateStr);
        }).toList();

        if (allTests.isEmpty) {
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            header,
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text("No tests recorded for this month.",
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  textAlign: TextAlign.center),
            ),
          ]);
        }

        // ── Compute per-subject grouping ───────────────────────
        // Map: subject → list of {marks, outOf, date}
        final Map<String, List<Map<String, dynamic>>> bySubject = {};
        for (final doc in allTests) {
          final d       = doc.data() as Map<String, dynamic>;
          final subject = d["subject"] as String? ?? "Unknown";
          bySubject.putIfAbsent(subject, () => []);
          bySubject[subject]!.add({
            "marks":  double.tryParse(d["marks"]  ?? "0") ?? 0,
            "out_of": double.tryParse(d["out_of"] ?? "100") ?? 100,
            "date":   d["date"] ?? "",
          });
        }

        // ── Overall average across ALL subjects ────────────────
        double totalMarksSum = 0, totalOutOfSum = 0;
        for (final tests in bySubject.values) {
          for (final t in tests) {
            totalMarksSum += (t["marks"] as double);
            totalOutOfSum += (t["out_of"] as double);
          }
        }
        final overallPct   = totalOutOfSum > 0 ? (totalMarksSum / totalOutOfSum) * 100 : 0.0;
        final overallGrade = _grade(overallPct);
        final overallColor = _gradeColor(overallPct);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            header,
            const SizedBox(height: 12),

            // ── Per-subject test table card ──────────────────
            Container(
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: Column(
                children: [
                  // Table header row
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                    child: Row(
                      children: [
                        Expanded(flex: 3, child: Text("Subject",
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary))),
                        Expanded(flex: 2, child: Text("Date",
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary))),
                        Expanded(flex: 2, child: Text("Total",
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary))),
                        Expanded(flex: 2, child: Text("Obtained",
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                            textAlign: TextAlign.right)),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: AppColors.divider),

                  // Test rows per subject
                  ...bySubject.entries.expand((entry) {
                    final subject = entry.key;
                    final tests   = entry.value;
                    return tests.map((t) {
                      final marks     = t["marks"]  as double;
                      final outOf     = t["out_of"] as double;
                      final pct       = outOf > 0 ? (marks / outOf) * 100 : 0.0;
                      final rowColor  = _gradeColor(pct);
                      // Format date dd Mon
                      String dateLabel = t["date"] as String;
                      try {
                        final parts = dateLabel.split("-");
                        if (parts.length == 3) {
                          final monthIndex = int.tryParse(parts[1]) ?? 0;
                          if (monthIndex >= 1 && monthIndex <= 12) {
                            dateLabel = "${parts[2]} ${months[monthIndex]}";
                          }
                        }
                      } catch (_) {}

                      return Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Text(subject,
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(dateLabel,
                                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(outOf.toStringAsFixed(0),
                                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: rowColor.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        "${marks.toStringAsFixed(0)}/${outOf.toStringAsFixed(0)}",
                                        style: TextStyle(fontSize: 12, color: rowColor, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1, color: AppColors.divider, indent: 16, endIndent: 16),
                        ],
                      );
                    });
                  }).toList(),

                  // ── Average % + Overall Grade footer ──────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                    child: Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: overallColor.withOpacity(0.10),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: overallColor.withOpacity(0.3)),
                                ),
                                child: Text(
                                  "Avg ${overallPct.toStringAsFixed(1)}%",
                                  style: TextStyle(fontSize: 12, color: overallColor, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: overallColor,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            "Grade  $overallGrade",
                            style: const TextStyle(color: AppColors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════
// ADD STUDENTS SCREEN
// ════════════════════════════════════════════════════════════════
class AddStudents extends StatefulWidget {
  final String? preselectedBatchId;
  const AddStudents({super.key, this.preselectedBatchId});
  @override
  State<AddStudents> createState() => _AddStudentsState();
}

class _AddStudentsState extends State<AddStudents> {
  // Backend: form controllers
  int _batchDurationMonths = 1;
  final _nameController         = TextEditingController();
  final _parentsEmailController = TextEditingController();
  final _parentPhoneController  = TextEditingController();
  final _rollnoController       = TextEditingController();
  final _db = DatabaseHelper();
  String? selectedBatchId;
  double _batchMonthlyFee = 0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Backend: pre-fill batch if coming from BatchStudentsScreen
    selectedBatchId = widget.preselectedBatchId;
    if (selectedBatchId != null) _fetchBatchFee(selectedBatchId!);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _parentsEmailController.dispose();
    _parentPhoneController.dispose();
    _rollnoController.dispose();
    super.dispose();
  }

  // Backend: fetch the batch's monthly fee to use as initial fees_due
  Future<void> _fetchBatchFee(String batchId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection("teachers").doc(_db.teacherId)
          .collection("batches").doc(batchId).get();
      if (mounted) setState(() {
        _batchMonthlyFee     = (doc["monthly_fee"]      ?? 0).toDouble();
        _batchDurationMonths = (doc["duration_months"]  ?? 1) as int; // NEW
      });
    } catch (_) {}
  }

  // Backend: validate and save student; fees_due = monthly_fee × duration_months
  Future<void> _addStudent() async {
    final name        = _nameController.text.trim();
    final parentEmail = _parentsEmailController.text.trim();
    final parentPhone = _parentPhoneController.text.trim();
    final rollno      = _rollnoController.text.trim();

    if (name.isEmpty || parentEmail.isEmpty || parentPhone.isEmpty) {
      _showSnack("Name, email and phone are required");
      return;
    }
    if (selectedBatchId == null) {
      _showSnack("Please select a batch");
      return;
    }

    setState(() => _isLoading = true);

    // Backend: total fee = monthly fee × batch duration months
    final totalFee = _batchMonthlyFee * _batchDurationMonths;

    await _db.addStudent(
      name: name,
      parentEmail: parentEmail,
      parentPhone: parentPhone,
      batchId: selectedBatchId!,
      rollno: rollno,
      feesDue: totalFee,  // CHANGED: was _batchMonthlyFee, now full course fee
    );

    if (mounted) {
      setState(() => _isLoading = false);
      _showSnack("Student added!", color: AppColors.success);
      _nameController.clear();
      _parentPhoneController.clear();
      _parentsEmailController.clear();
      _rollnoController.clear();
      if (widget.preselectedBatchId == null) setState(() => selectedBatchId = null);
    }
  }

  void _showSnack(String msg, {Color? color}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      duration: const Duration(seconds: 2),
    ));
  }

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
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 16),

            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: "Student Name *",
                prefixIcon: Icon(Icons.person_outline, color: AppColors.primary),
              ),
            ),
            const SizedBox(height: 14),

            TextField(
              controller: _parentsEmailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: "Parent's Email *",
                prefixIcon: Icon(Icons.email_outlined, color: AppColors.primary),
              ),
            ),
            const SizedBox(height: 14),

            TextField(
              controller: _parentPhoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: "Parent's Phone *",
                prefixIcon: Icon(Icons.phone_outlined, color: AppColors.primary),
              ),
            ),
            const SizedBox(height: 14),

            TextField(
              controller: _rollnoController,
              decoration: const InputDecoration(
                labelText: "Roll No (Optional)",
                prefixIcon: Icon(Icons.tag, color: AppColors.primary),
              ),
            ),
            const SizedBox(height: 14),

            // Backend: live batch dropdown — auto-loads fee when selected
            StreamBuilder<QuerySnapshot>(
              stream: _db.getBatches(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  // UI: clear guidance — create batch first
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.warning.withOpacity(0.4)),
                    ),
                    child: const Text(
                      "⚠️ No batches yet. Go back to Dashboard and create a batch first.",
                      style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
                    ),
                  );
                }

                return DropdownButtonFormField<String>(
                  value: selectedBatchId,
                  decoration: const InputDecoration(
                    labelText: "Select Batch *",
                    prefixIcon: Icon(Icons.class_outlined, color: AppColors.primary),
                  ),
                  dropdownColor: AppColors.background,
                  items: snapshot.data!.docs.map((batch) {
                    final fee = (batch["monthly_fee"] ?? 0).toStringAsFixed(0);
                    return DropdownMenuItem<String>(
                      value: batch.id,
                      // UI: show fee in dropdown so teacher knows what they're assigning
                      child: Text("${batch["name"]}  ·  ₹$fee/mo"),
                    );
                  }).toList(),
                  onChanged: (value) async {
                    setState(() => selectedBatchId = value);
                    if (value != null) await _fetchBatchFee(value);
                  },
                );
              },
            ),

            // UI: auto-fee info notice — shows TOTAL fee (monthly × duration)
            if (selectedBatchId != null && _batchMonthlyFee > 0) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.success.withOpacity(0.3)),
                ),
                child: Text(
                  "✓ Total fees due: ₹${(_batchMonthlyFee * _batchDurationMonths).toStringAsFixed(0)}"
                  "  (₹${_batchMonthlyFee.toStringAsFixed(0)} × $_batchDurationMonths months)",
                  style: const TextStyle(fontSize: 12, color: AppColors.success),
                ),
              ),
            ],

            const SizedBox(height: 28),

            _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : ElevatedButton.icon(
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
// ADD BATCH SCREEN
// ════════════════════════════════════════════════════════════════
class AddBatch extends StatefulWidget {
  const AddBatch({super.key});
  @override
  State<AddBatch> createState() => _AddBatchState();
}

class _AddBatchState extends State<AddBatch> {
  // Backend: form controllers
  final _nameController          = TextEditingController();
  final _subjectController       = TextEditingController();
  final _scheduleController      = TextEditingController();
  final _monthlyFeeController    = TextEditingController();
  final _durationController      = TextEditingController();
  final _db = DatabaseHelper();

  DateTime? _startDate;       // NEW: chosen start date
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _subjectController.dispose();
    _scheduleController.dispose();
    _monthlyFeeController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  // UI: opens date picker and stores result
  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  // Backend: validate and save batch to Firestore
  Future<void> _addBatch() async {
    final name       = _nameController.text.trim();
    final subject    = _subjectController.text.trim();
    final schedule   = _scheduleController.text.trim();
    final monthlyFee = double.tryParse(_monthlyFeeController.text.trim());
    final duration   = int.tryParse(_durationController.text.trim());

    if (name.isEmpty)       { _showSnack("Batch name is required"); return; }
    if (monthlyFee == null) { _showSnack("Enter a valid monthly fee"); return; }
    if (duration == null || duration < 1) { _showSnack("Enter a valid duration (months)"); return; }
    if (_startDate == null) { _showSnack("Please select a start date"); return; }

    setState(() => _isLoading = true);
    await _db.addBatch(
      name: name,
      subject: subject,
      schedule: schedule,
      monthlyFee: monthlyFee,
      startDate: _startDate!,
      durationMonths: duration,
    );

    if (mounted) {
      setState(() => _isLoading = false);
      _showSnack("Batch created!", color: AppColors.success);
      Navigator.pop(context);
    }
  }

  void _showSnack(String msg, {Color? color}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    // UI: live total fee preview
    final monthlyFee = double.tryParse(_monthlyFeeController.text.trim()) ?? 0;
    final duration   = int.tryParse(_durationController.text.trim()) ?? 0;
    final totalFee   = monthlyFee * duration;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text("Create Batch")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text("Batch Details",
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 16),

            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: "Batch Name *",
                prefixIcon: Icon(Icons.class_outlined, color: AppColors.primary),
                hintText: "e.g. Morning Math, Science Std 10",
              ),
            ),
            const SizedBox(height: 14),

            TextField(
              controller: _subjectController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: "Subject",
                prefixIcon: Icon(Icons.menu_book_outlined, color: AppColors.primary),
              ),
            ),
            const SizedBox(height: 14),

            TextField(
              controller: _scheduleController,
              decoration: const InputDecoration(
                labelText: "Schedule  (e.g. Mon-Wed-Fri | 5 PM)",
                prefixIcon: Icon(Icons.schedule_outlined, color: AppColors.primary),
              ),
            ),
            const SizedBox(height: 14),

            // UI: Monthly Fee + Duration side by side
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _monthlyFeeController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}), // UI: refresh total preview
                    decoration: const InputDecoration(
                      labelText: "Monthly Fee *",
                      prefixIcon: Icon(Icons.currency_rupee, color: AppColors.primary),
                      hintText: "1500",
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _durationController,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}), // UI: refresh total preview
                    decoration: const InputDecoration(
                      labelText: "Duration (months) *",
                      prefixIcon: Icon(Icons.timelapse_outlined, color: AppColors.primary),
                      hintText: "12",
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // UI: Start Date picker tile
            GestureDetector(
              onTap: _pickStartDate,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _startDate != null ? AppColors.primary : AppColors.divider,
                    width: _startDate != null ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined, color: AppColors.primary, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _startDate == null
                            ? "Start Date *"
                            : "${_startDate!.day}/${_startDate!.month}/${_startDate!.year}",
                        style: TextStyle(
                          fontSize: 15,
                          color: _startDate == null ? AppColors.textSecondary : AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const Icon(Icons.arrow_drop_down, color: AppColors.textSecondary),
                  ],
                ),
              ),
            ),

            // UI: Total fee preview card — auto-calculated, no manual entry
            if (totalFee > 0) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withOpacity(0.25)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calculate_outlined, color: AppColors.primary, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Total Fee per Student:  ₹${totalFee.toStringAsFixed(0)}  "
                        "(₹${monthlyFee.toStringAsFixed(0)} × $duration months)",
                        style: const TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 28),

            _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : ElevatedButton.icon(
                    onPressed: _addBatch,
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text("Create Batch"),
                  ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// EDIT BATCH SCREEN — edit existing batch details
// UI: same form as AddBatch but pre-filled. "Save Changes" replaces "Create".
// Backend: updates Firestore batch doc.
// ════════════════════════════════════════════════════════════════
class EditBatch extends StatefulWidget {
  final String batchId, initialName, initialSubject, initialSchedule, initialMonthlyFee;
  const EditBatch({
    super.key,
    required this.batchId,
    required this.initialName,
    required this.initialSubject,
    required this.initialSchedule,
    required this.initialMonthlyFee,
  });
  @override
  State<EditBatch> createState() => _EditBatchState();
}

class _EditBatchState extends State<EditBatch> {
  late final TextEditingController _nameController;
  late final TextEditingController _subjectController;
  late final TextEditingController _scheduleController;
  late final TextEditingController _monthlyFeeController;
  final _db = DatabaseHelper();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Backend: pre-fill with existing values
    _nameController       = TextEditingController(text: widget.initialName);
    _subjectController    = TextEditingController(text: widget.initialSubject);
    _scheduleController   = TextEditingController(text: widget.initialSchedule);
    _monthlyFeeController = TextEditingController(text: widget.initialMonthlyFee);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _subjectController.dispose();
    _scheduleController.dispose();
    _monthlyFeeController.dispose();
    super.dispose();
  }

  // Backend: update existing batch doc in Firestore
  Future<void> _saveBatch() async {
    final name       = _nameController.text.trim();
    final monthlyFee = double.tryParse(_monthlyFeeController.text.trim());

    if (name.isEmpty) { _showSnack("Batch name is required"); return; }
    if (monthlyFee == null) { _showSnack("Enter a valid monthly fee"); return; }

    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance
          .collection("teachers").doc(_db.teacherId)
          .collection("batches").doc(widget.batchId)
          .update({
            "name":        name,
            "subject":     _subjectController.text.trim(),
            "schedule":    _scheduleController.text.trim(),
            "monthly_fee": monthlyFee,
          });
      if (mounted) {
        _showSnack("Batch updated!", color: AppColors.success);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) _showSnack("Failed to update. Try again.");
    }
    if (mounted) setState(() => _isLoading = false);
  }

  void _showSnack(String msg, {Color? color}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text("Edit Batch")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text("Batch Details",
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 16),

            TextField(controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                    labelText: "Batch Name *",
                    prefixIcon: Icon(Icons.class_outlined, color: AppColors.primary))),
            const SizedBox(height: 14),

            TextField(controller: _subjectController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                    labelText: "Subject",
                    prefixIcon: Icon(Icons.menu_book_outlined, color: AppColors.primary))),
            const SizedBox(height: 14),

            TextField(controller: _scheduleController,
                decoration: const InputDecoration(
                    labelText: "Schedule",
                    prefixIcon: Icon(Icons.schedule_outlined, color: AppColors.primary))),
            const SizedBox(height: 14),

            TextField(controller: _monthlyFeeController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                    labelText: "Monthly Fee *",
                    prefixIcon: Icon(Icons.currency_rupee, color: AppColors.primary))),
            const SizedBox(height: 28),

            _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : ElevatedButton.icon(
                    onPressed: _saveBatch,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text("Save Changes"),
                  ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// SELECT BATCH FOR TEST — step 1 of Add Test Marks flow
// ════════════════════════════════════════════════════════════════
class SelectBatchForTestScreen extends StatelessWidget {
  const SelectBatchForTestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final teacherId = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text("Add Test Marks")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("teachers").doc(teacherId).collection("batches")
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }
          final batches = snapshot.data!.docs;
          if (batches.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text("No batches yet. Create a batch from Dashboard.",
                    style: TextStyle(color: AppColors.textSecondary), textAlign: TextAlign.center),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: batches.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final batch = batches[index];
              final data  = batch.data() as Map<String, dynamic>;
              return GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddTestMarksScreen(
                      batchId:   batch.id,
                      batchName: data["name"] ?? "Unnamed",
                    ),
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.lavender.withOpacity(0.4)),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 2))],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.lavender.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.class_rounded, color: AppColors.lavender, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(data["name"] ?? "Unnamed",
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                            if ((data["subject"] ?? "").toString().isNotEmpty)
                              Text(data["subject"],
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: AppColors.textSecondary),
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
}

// ════════════════════════════════════════════════════════════════
// ADD TEST MARKS SCREEN
// Flow: enter subject + outOf ONCE → cycle through students one by one
// Backend: saves to teachers/{uid}/students/{sid}/tests/{auto-id}
// ════════════════════════════════════════════════════════════════
class AddTestMarksScreen extends StatefulWidget {
  final String batchId, batchName;
  const AddTestMarksScreen({required this.batchId, required this.batchName, super.key});
  @override
  State<AddTestMarksScreen> createState() => _AddTestMarksScreenState();
}

class _AddTestMarksScreenState extends State<AddTestMarksScreen> {
  final String teacherId = FirebaseAuth.instance.currentUser!.uid;

  // Step 1: subject setup
  bool _setupDone = false;
  final _subjectCtrl = TextEditingController();
  final _outOfCtrl   = TextEditingController();
  DateTime _testDate = DateTime.now();

  // Step 2: per-student entry
  List<QueryDocumentSnapshot> _students = [];
  int _currentIndex = 0;
  final _marksCtrl = TextEditingController();
  bool _saving     = false;
  bool _loadingStudents = true;

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _outOfCtrl.dispose();
    _marksCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadStudents() async {
    final snap = await FirebaseFirestore.instance
        .collection("teachers").doc(teacherId).collection("students")
        .where("batch_id", isEqualTo: widget.batchId)
        .where("is_active", isEqualTo: true)
        .get();
    if (mounted) setState(() { _students = snap.docs; _loadingStudents = false; });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _testDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _testDate = picked);
  }

  void _confirmSetup() {
    if (_subjectCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Enter subject name")));
      return;
    }
    final outOf = double.tryParse(_outOfCtrl.text.trim());
    if (outOf == null || outOf <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Enter valid total marks")));
      return;
    }
    if (_students.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No active students in this batch")));
      return;
    }
    setState(() { _setupDone = true; _currentIndex = 0; });
  }

  Future<void> _saveAndNext() async {
    final marksText = _marksCtrl.text.trim();
    if (marksText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Enter marks for this student")));
      return;
    }
    final marks = double.tryParse(marksText);
    if (marks == null || marks < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Enter valid marks")));
      return;
    }
    final outOf = double.tryParse(_outOfCtrl.text.trim()) ?? 0;
    if (marks > outOf) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Marks cannot exceed total marks")));
      return;
    }

    setState(() => _saving = true);
    final student  = _students[_currentIndex];
    final dateStr  = _testDate.toIso8601String().split("T")[0];

    await FirebaseFirestore.instance
        .collection("teachers").doc(teacherId)
        .collection("students").doc(student.id)
        .collection("tests").add({
      "subject":  _subjectCtrl.text.trim(),
      "marks":    marksText,
      "out_of":   _outOfCtrl.text.trim(),
      "date":     dateStr,
    });

    if (mounted) {
      setState(() => _saving = false);
      _marksCtrl.clear();

      if (_currentIndex < _students.length - 1) {
        setState(() => _currentIndex++);
      } else {
        // All done
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("All marks saved!"),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context);
      }
    }
  }

  void _skipStudent() {
    _marksCtrl.clear();
    if (_currentIndex < _students.length - 1) {
      setState(() => _currentIndex++);
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.batchName),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: _setupDone && _students.isNotEmpty
              ? LinearProgressIndicator(
                  value: (_currentIndex + 1) / _students.length,
                  backgroundColor: AppColors.white.withOpacity(0.3),
                  valueColor: const AlwaysStoppedAnimation(AppColors.white),
                )
              : const SizedBox.shrink(),
        ),
      ),
      body: _loadingStudents
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _setupDone
              ? _buildStudentEntry()
              : _buildSetupStep(),
    );
  }

  // ── Step 1: Subject setup ──────────────────────────────────────
  Widget _buildSetupStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.lavender.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.lavender.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.lavender.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.quiz_rounded, color: AppColors.lavender, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Test Setup",
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                      Text("${_students.length} students · ${widget.batchName}",
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          const Text("Test Details",
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 16),

          TextField(
            controller: _subjectCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: "Enter Subject",
              prefixIcon: Icon(Icons.menu_book_outlined, color: AppColors.primary),
              hintText: "e.g. Math, Science",
            ),
          ),
          const SizedBox(height: 14),

          TextField(
            controller: _outOfCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: "Total Marks (Out Of) *",
              prefixIcon: Icon(Icons.bar_chart_rounded, color: AppColors.primary),
              hintText: "e.g. 100",
            ),
          ),
          const SizedBox(height: 14),

          // Date picker
          GestureDetector(
            onTap: _pickDate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary, width: 2),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_outlined, color: AppColors.primary, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "${_testDate.day}/${_testDate.month}/${_testDate.year}",
                      style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down, color: AppColors.textSecondary),
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),

          ElevatedButton.icon(
            onPressed: _confirmSetup,
            icon: const Icon(Icons.arrow_forward),
            label: const Text("Start Entering Marks"),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.lavender),
          ),
        ],
      ),
    );
  }

  // ── Step 2: Per-student marks entry ────────────────────────────
  Widget _buildStudentEntry() {
    if (_students.isEmpty) {
      return const Center(
        child: Text("No students found", style: TextStyle(color: AppColors.textSecondary)),
      );
    }
    final student     = _students[_currentIndex];
    final studentData = student.data() as Map<String, dynamic>;
    final name        = studentData["name"] ?? "Unknown";
    final outOf       = double.tryParse(_outOfCtrl.text.trim()) ?? 100;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Progress indicator text
          Text(
            "Student ${_currentIndex + 1} of ${_students.length}",
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          // Student card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: AppColors.white.withOpacity(0.2),
                  child: Text(
                    name[0].toUpperCase(),
                    style: const TextStyle(color: AppColors.white, fontSize: 26, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 12),
                Text(name,
                    style: const TextStyle(color: AppColors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  "${_subjectCtrl.text.trim()}  ·  Out of ${outOf.toStringAsFixed(0)}",
                  style: TextStyle(color: AppColors.white.withOpacity(0.75), fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Marks input
          TextField(
            controller: _marksCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              labelText: "Marks Obtained",
              prefixIcon: const Icon(Icons.edit_rounded, color: AppColors.primary),
              suffixText: "/ ${outOf.toStringAsFixed(0)}",
              suffixStyle: const TextStyle(fontSize: 16, color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(height: 28),

          // Save & Next
          _saving
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : ElevatedButton.icon(
                  onPressed: _saveAndNext,
                  icon: Icon(_currentIndex < _students.length - 1
                      ? Icons.arrow_forward
                      : Icons.check_circle_outline),
                  label: Text(_currentIndex < _students.length - 1 ? "Save & Next" : "Save & Finish"),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.lavender),
                ),
          const SizedBox(height: 12),

          // Skip button
          OutlinedButton(
            onPressed: _skipStudent,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              side: const BorderSide(color: AppColors.divider),
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text("Skip (Absent / No Data)"),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// EDIT STUDENT SCREEN — edit existing student details
// UI: pre-filled form with Save Changes button.
// Backend: updates Firestore student doc. Does NOT modify fees_paid.
// ════════════════════════════════════════════════════════════════
class EditStudent extends StatefulWidget {
  final String studentId;
  final Map<String, dynamic> initialData;
  const EditStudent({super.key, required this.studentId, required this.initialData});
  @override
  State<EditStudent> createState() => _EditStudentState();
}

class _EditStudentState extends State<EditStudent> {
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _rollnoController;
  final _db = DatabaseHelper();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Backend: pre-fill with existing values
    _nameController   = TextEditingController(text: widget.initialData["name"]         ?? "");
    _emailController  = TextEditingController(text: widget.initialData["parent_email"] ?? "");
    _phoneController  = TextEditingController(text: widget.initialData["parent_phone"] ?? "");
    _rollnoController = TextEditingController(text: widget.initialData["roll_no"]      ?? "");
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _rollnoController.dispose();
    super.dispose();
  }

  // Backend: update student doc in Firestore
  Future<void> _saveStudent() async {
    final name  = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();

    if (name.isEmpty || email.isEmpty || phone.isEmpty) {
      _showSnack("Name, email and phone are required");
      return;
    }

    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance
          .collection("teachers").doc(_db.teacherId)
          .collection("students").doc(widget.studentId)
          .update({
            "name":         name,
            "parent_email": email,
            "parent_phone": phone,
            "roll_no":      _rollnoController.text.trim(),
          });
      if (mounted) {
        _showSnack("Student updated!", color: AppColors.success);
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) _showSnack("Failed to update. Try again.");
    }
    if (mounted) setState(() => _isLoading = false);
  }

  void _showSnack(String msg, {Color? color}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text("Edit Student")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text("Student Details",
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 16),

            TextField(controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                    labelText: "Student Name *",
                    prefixIcon: Icon(Icons.person_outline, color: AppColors.primary))),
            const SizedBox(height: 14),

            TextField(controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                    labelText: "Parent's Email *",
                    prefixIcon: Icon(Icons.email_outlined, color: AppColors.primary))),
            const SizedBox(height: 14),

            TextField(controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                    labelText: "Parent's Phone *",
                    prefixIcon: Icon(Icons.phone_outlined, color: AppColors.primary))),
            const SizedBox(height: 14),

            TextField(controller: _rollnoController,
                decoration: const InputDecoration(
                    labelText: "Roll No (Optional)",
                    prefixIcon: Icon(Icons.tag, color: AppColors.primary))),
            const SizedBox(height: 28),

            _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : ElevatedButton.icon(
                    onPressed: _saveStudent,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text("Save Changes"),
                  ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// ATTENDANCE SCREEN — daily attendance per batch (no Scaffold)
// UI: tap-to-toggle card grid instead of checkboxes.
//     Tapping a card INSTANTLY changes color — no Firestore latency perceived.
//     Green = Present, White = Absent. Optimistic UI update.
// Backend: toggleAttendance uses Firestore transaction for consistency.
// ════════════════════════════════════════════════════════════════
class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});
  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  // Backend: Firestore + teacher UID
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String teacherId      = FirebaseAuth.instance.currentUser!.uid;
  final _dbHelper             = DatabaseHelper();

  String? selectedBatchId;

  // Backend: today's ISO date used as attendance doc ID
  String get today => DateTime.now().toIso8601String().split('T')[0];

  // UI: optimistic local state map — studentId → isPresent
  // This makes the UI feel instant even if Firestore takes 300ms+.
  final Map<String, bool> _localState = {};

  // Backend: Firestore transaction — atomically mark/unmark attendance
  Future<void> _toggleAttendance({
    required String studentId,
    required String batchId,
    required bool markPresent,
  }) async {
    // UI: optimistic update first — user sees instant response
    setState(() => _localState[studentId] = markPresent);

    final studentRef   = _db.collection("teachers").doc(teacherId).collection("students").doc(studentId);
    final batchRef     = _db.collection("teachers").doc(teacherId).collection("batches").doc(batchId);
    final attendanceRef = studentRef.collection("attendance").doc(today);

    try {
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
          // Backend: delete attendance doc + decrement present_days
          transaction.delete(attendanceRef);
          transaction.update(studentRef, {"present_days": FieldValue.increment(-1)});
          // NOTE: total_days NOT decremented — a working day stays counted
        }
      });
    } catch (_) {
      // UI: revert optimistic update on failure
      if (mounted) setState(() => _localState[studentId] = !markPresent);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // UI: batch selector
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
            if (selectedBatchId != null && !docs.any((d) => d.id == selectedBatchId)) {
              selectedBatchId = null;
            }

            // UI: empty state guidance
            if (docs.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(32),
                child: Text("No batches yet. Create a batch from Dashboard.",
                    style: TextStyle(color: AppColors.textSecondary), textAlign: TextAlign.center),
              );
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
                    hint: const Text("Select Batch", style: TextStyle(color: AppColors.textSecondary)),
                    value: selectedBatchId,
                    dropdownColor: AppColors.background,
                    icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.primary),
                    items: docs.map((doc) => DropdownMenuItem<String>(
                      value: doc.id,
                      child: Text(doc["name"], style: const TextStyle(color: AppColors.textPrimary)),
                    )).toList(),
                    onChanged: (value) => setState(() {
                      selectedBatchId = value;
                      _localState.clear(); // reset optimistic state for new batch
                    }),
                  ),
                ),
              ),
            );
          },
        ),

        // UI: date + summary label
        if (selectedBatchId != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, size: 13, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Text("$today  ·  Tap a card to mark present",
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),

        // UI + Backend: student cards grid — instant visual toggle
        if (selectedBatchId != null)
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _db
                  .collection("teachers").doc(teacherId).collection("students")
                  .where("batch_id", isEqualTo: selectedBatchId)
                  .where("is_active", isEqualTo: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                }

                final students = snapshot.data!.docs;
                if (students.isEmpty) {
                  return const Center(
                    child: Text("No students in this batch", style: TextStyle(color: AppColors.textSecondary)),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  itemCount: students.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final doc       = students[index];
                    final studentId = doc.id;
                    final name      = doc["name"] ?? "Unknown";

                    // Backend: per-student attendance stream for today
                    return StreamBuilder<DocumentSnapshot>(
                      stream: _db
                          .collection("teachers").doc(teacherId)
                          .collection("students").doc(studentId)
                          .collection("attendance").doc(today)
                          .snapshots(),
                      builder: (context, attSnap) {
                        // UI: use local optimistic state if available,
                        //     else fall back to Firestore stream
                        final firestoreMarked = attSnap.data?.exists ?? false;
                        final marked = _localState.containsKey(studentId)
                            ? _localState[studentId]!
                            : firestoreMarked;

                        // UI: large tap-friendly attendance card
                        // No checkbox — entire card taps to toggle
                        return GestureDetector(
                          onTap: () => _toggleAttendance(
                            studentId:   studentId,
                            batchId:     selectedBatchId!,
                            markPresent: !marked,
                          ),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: marked ? AppColors.success.withOpacity(0.12) : AppColors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: marked ? AppColors.success : AppColors.divider,
                                width: marked ? 2.0 : 1.0,
                              ),
                            ),
                            child: Row(
                              children: [
                                // UI: avatar — turns green when present
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: marked
                                      ? AppColors.success
                                      : AppColors.primary.withOpacity(0.10),
                                  child: marked
                                      ? const Icon(Icons.check, color: AppColors.white, size: 18)
                                      : Text(
                                          name[0].toUpperCase(),
                                          style: const TextStyle(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                ),
                                const SizedBox(width: 14),

                                // UI: name + status label
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(name,
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: marked ? AppColors.success : AppColors.textPrimary,
                                          )),
                                      Text(
                                        marked ? "Present ✓" : "Absent  —  Tap to mark present",
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: marked ? AppColors.success : AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // UI: toggle pill indicator
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: marked ? AppColors.success : AppColors.divider,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    marked ? "P" : "A",
                                    style: TextStyle(
                                      color: marked ? AppColors.white : AppColors.textSecondary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
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

        // UI: placeholder when no batch selected
        if (selectedBatchId == null)
          const Expanded(
            child: Center(
              child: Text("Select a batch above to take attendance",
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
          ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
// PAYMENT SCREEN — fees management (no Scaffold)
// UI: "Mark Paid" = one tap pays full outstanding amount.
//     No half payments — teachers confirmed this is simpler.
//     Auto-fee due: set by batch monthly fee, NOT manual entry.
//     Month selector: view/manage fees by month (future auto-increment).
// Backend: reads fees_due and fees_paid from student doc.
//          addPayment in DatabaseHelper handles the math.
// ════════════════════════════════════════════════════════════════
class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});
  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  // Backend: db helper + selected batch
  final DatabaseHelper _dbHelper = DatabaseHelper();
  String? selectedBatchId;
  double monthlyFee = 0;

  // UI: confirm and record full payment (no dialog with input field — just confirm)
  void _confirmPayFull(String studentId, String name, double amount) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Confirm Full Payment",
                style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
            Text(name,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, fontWeight: FontWeight.normal)),
          ],
        ),
        content: Text(
          "Mark ₹${amount.toStringAsFixed(0)} as paid for $name?",
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              minimumSize: const Size(100, 44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              // Backend: record the full outstanding amount as a payment
              await _dbHelper.addPayment(studentId: studentId, amount: amount);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text("Confirm"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // UI: batch selector
        StreamBuilder<QuerySnapshot>(
          stream: _dbHelper.getBatches(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(color: AppColors.primary));
            }

            final docs = snapshot.data!.docs;
            if (selectedBatchId != null && !docs.any((d) => d.id == selectedBatchId)) {
              selectedBatchId = null;
            }

            if (docs.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(32),
                child: Text("No batches yet. Create one from Dashboard.",
                    style: TextStyle(color: AppColors.textSecondary), textAlign: TextAlign.center),
              );
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
                    hint: const Text("Select Batch", style: TextStyle(color: AppColors.textSecondary)),
                    value: selectedBatchId,
                    dropdownColor: AppColors.background,
                    icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.primary),
                    items: docs.map((doc) => DropdownMenuItem<String>(
                      value: doc.id,
                      child: Text(doc["name"], style: const TextStyle(color: AppColors.textPrimary)),
                    )).toList(),
                    onChanged: (val) async {
                      setState(() => selectedBatchId = val);
                      if (val != null) {
                        // Backend: fetch batch monthly fee
                        final batchDoc = await FirebaseFirestore.instance
                            .collection("teachers").doc(_dbHelper.teacherId)
                            .collection("batches").doc(val).get();
                        if (mounted) setState(() => monthlyFee = (batchDoc["monthly_fee"] ?? 0).toDouble());
                      }
                    },
                  ),
                ),
              ),
            );
          },
        ),

        // UI: student fee cards
        if (selectedBatchId != null)
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("teachers").doc(_dbHelper.teacherId)
                  .collection("students")
                  .where("batch_id", isEqualTo: selectedBatchId)
                  .where("is_active", isEqualTo: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                }

                final students = snapshot.data!.docs;
                if (students.isEmpty) {
                  return const Center(
                    child: Text("No students in this batch",
                        style: TextStyle(color: AppColors.textSecondary)),
                  );
                }

                // UI: summary bar at top — total collected vs pending
                double totalPaid = 0, totalDue = 0;
                for (final d in students) {
                  final paid     = (d["fees_paid"] ?? 0.0).toDouble();
                  final due      = (d["fees_due"]  ?? monthlyFee).toDouble();
                  totalPaid     += paid;
                  totalDue      += (due - paid).clamp(0.0, double.infinity);
                }

                return Column(
                  children: [
                    // UI: batch-level summary banner
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Row(
                        children: [
                          Expanded(child: _summaryChip("Collected", "₹${totalPaid.toStringAsFixed(0)}", AppColors.success)),
                          const SizedBox(width: 8),
                          Expanded(child: _summaryChip("Pending", "₹${totalDue.toStringAsFixed(0)}", AppColors.warning)),
                        ],
                      ),
                    ),

                    // UI: student fee rows
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                        itemCount: students.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final doc       = students[index];
                          final studentId = doc.id;
                          final name      = doc["name"] ?? "Unknown";
                          final paid      = (doc["fees_paid"] ?? 0.0).toDouble();
                          final due       = (doc["fees_due"]  ?? monthlyFee).toDouble();
                          final remaining = (due - paid).clamp(0.0, double.infinity);
                          final isFullyPaid = remaining <= 0;

                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isFullyPaid
                                    ? AppColors.success.withOpacity(0.5)
                                    : AppColors.warning.withOpacity(0.5),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))
                              ],
                            ),
                            child: Row(
                              children: [
                                // UI: status icon
                                Container(
                                  width: 42, height: 42,
                                  decoration: BoxDecoration(
                                    color: (isFullyPaid ? AppColors.success : AppColors.warning).withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    isFullyPaid ? Icons.check_circle_outline : Icons.warning_amber_rounded,
                                    color: isFullyPaid ? AppColors.success : AppColors.warning,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 12),

                                // UI: name + fee chips
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(name,
                                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          _feeChip("₹${paid.toStringAsFixed(0)} paid", AppColors.success),
                                          const SizedBox(width: 6),
                                          if (!isFullyPaid)
                                            _feeChip("₹${remaining.toStringAsFixed(0)} due", AppColors.warning),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                                // UI: "Mark Paid" — one tap, no number entry
                                // Shows ✓ when fully paid
                                if (!isFullyPaid)
                                  GestureDetector(
                                    onTap: () => _confirmPayFull(studentId, name, remaining),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: AppColors.success,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Text("Mark Paid",
                                          style: TextStyle(color: AppColors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                    ),
                                  )
                                else
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppColors.success.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(Icons.check_circle, color: AppColors.success, size: 20),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

        // UI: placeholder
        if (selectedBatchId == null)
          const Expanded(
            child: Center(
              child: Text("Select a batch to manage fees",
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
          ),
      ],
    );
  }

  // UI: summary chip for collected/pending totals
  Widget _summaryChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(label == "Collected" ? Icons.arrow_downward : Icons.arrow_upward,
              size: 14, color: color),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500)),
              Text(value, style: TextStyle(fontSize: 14, color: color, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  // UI: small colored fee chip
  Widget _feeChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// PROFILE SCREEN — teacher profile + sign out (no Scaffold)
// UI: shows display name and email from Firebase Auth.
// Backend: reads from FirebaseAuth.instance.currentUser.
// ════════════════════════════════════════════════════════════════
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Backend: get current user from Firebase Auth
    final user        = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName ?? "Teacher";
    final email       = user?.email       ?? "—";
    // Backend: format join date from user metadata
    final created     = user?.metadata.creationTime;
    final memberSince = created != null
        ? "${created.day}/${created.month}/${created.year}"
        : "—";

    return SingleChildScrollView(
      child: Column(
        children: [
          // UI: profile header
          Container(
            width: double.infinity,
            color: AppColors.primary,
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.white.withOpacity(0.5), width: 3),
                  ),
                  child: CircleAvatar(
                    radius: 44,
                    backgroundColor: AppColors.white.withOpacity(0.18),
                    child: Text(
                      displayName.isNotEmpty ? displayName[0].toUpperCase() : "T",
                      style: const TextStyle(color: AppColors.white, fontSize: 36, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(displayName,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.white)),
                const SizedBox(height: 4),
                Text(email,
                    style: TextStyle(fontSize: 14, color: AppColors.white.withOpacity(0.75))),
              ],
            ),
          ),

          // UI: info tiles
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _profileTile(Icons.school_outlined, "Role", "Teacher"),
                const SizedBox(height: 10),
                _profileTile(Icons.calendar_today_outlined, "Member Since", memberSince),
                const SizedBox(height: 10),
                _profileTile(Icons.email_outlined, "Email", email),
                const SizedBox(height: 24),

                // UI: sign out button
                OutlinedButton.icon(
                  onPressed: () => FirebaseAuth.instance.signOut(),
                  icon: const Icon(Icons.logout, color: AppColors.error),
                  label: const Text("Sign Out", style: TextStyle(color: AppColors.error)),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
                    side: const BorderSide(color: AppColors.error),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
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
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 1))],
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
              Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              Text(value,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            ],
          ),
        ],
      ),
    );
  }
}
