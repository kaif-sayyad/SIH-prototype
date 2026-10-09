import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/user_session.dart';
import '../services/auth_service.dart';

class AuthScreen extends StatefulWidget {
  final String lang;
  final Function(UserSession) onLoginSuccess;

  const AuthScreen({
    Key? key,
    required this.lang,
    required this.onLoginSuccess,
  }) : super(key: key);

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final AuthService _authService = AuthService();

  // Student inputs
  bool _isRegister = false;
  final _studentNameController = TextEditingController(text: 'Aarav Sharma');
  final _studentPhoneController = TextEditingController(text: '9876543210');
  final _studentPasswordController = TextEditingController(text: 'pass123');

  // Parent inputs
  final _parentCodeController = TextEditingController();
  final _parentNameController = TextEditingController(text: 'Rajesh Sharma');

  // Counsellor inputs
  final _counsellorIdController = TextEditingController(text: 'counsellor@skillpath.in');
  final _counsellorPinController = TextEditingController(text: 'counsellor123');

  // Admin inputs
  final _adminEmailController = TextEditingController(text: 'admin@example.com');
  final _adminPasswordController = TextEditingController(text: 'admin123');

  // Generated code dialog state
  String? _generatedParentCode;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  void _handleStudentAuth() async {
    setState(() => _errorMessage = '');
    try {
      if (_isRegister) {
        final session = await _authService.registerStudent(
          name: _studentNameController.text.trim(),
          phone: _studentPhoneController.text.trim(),
          password: _studentPasswordController.text.trim(),
        );
        setState(() {
          _generatedParentCode = session.parentAccessCode;
        });
        _showParentCodeDialog(session);
      } else {
        final session = await _authService.loginStudent(
          phone: _studentPhoneController.text.trim(),
          password: _studentPasswordController.text.trim(),
        );
        if (session != null) {
          widget.onLoginSuccess(session);
        }
      }
    } catch (e) {
      setState(() => _errorMessage = 'Authentication failed: $e');
    }
  }

  void _handleParentAuth() async {
    setState(() => _errorMessage = '');
    final code = _parentCodeController.text.trim();
    if (code.isEmpty) {
      setState(() => _errorMessage = 'Please enter your Parent Access Code');
      return;
    }

    final session = await _authService.loginParent(
      accessCode: code,
      parentName: _parentNameController.text.trim(),
    );

    if (session != null) {
      widget.onLoginSuccess(session);
    } else {
      setState(() => _errorMessage = 'Invalid Parent Access Code');
    }
  }

  void _showParentCodeDialog(UserSession session) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.vpn_key, color: Color(0xFFFF9933)),
            SizedBox(width: 8),
            Text('Parent Access Code Generated', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Give this unique code to your parent. They will use it to log in and review your career options in the shared family session:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade300),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    session.parentAccessCode,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      color: Color(0xFF1B365D),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, color: Color(0xFF1B365D)),
                    tooltip: 'Copy Code',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: session.parentAccessCode));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Parent Access Code copied to clipboard!')),
                      );
                    },
                  )
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1B365D),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(context);
              widget.onLoginSuccess(session);
            },
            child: const Text('Proceed to Portal'),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.school, size: 48, color: Color(0xFF1B365D)),
                  const SizedBox(height: 8),
                  Text(
                    widget.lang == 'mr' ? 'कौटुंबिक लॉगिन व नोंदणी' : 'Family Portal Sign In',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1B365D),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.lang == 'mr'
                        ? 'विद्यार्थी आणि पालकांसाठी एकात्मिक समुपदेशन'
                        : 'Collaborative Vocational Career Decision Support',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),

                  // Tabs: Student / Parent / Counsellor / Admin
                  TabBar(
                    controller: _tabController,
                    labelColor: const Color(0xFF1B365D),
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: const Color(0xFFFF9933),
                    indicatorWeight: 3,
                    isScrollable: true,
                    tabs: const [
                      Tab(text: 'Student'),
                      Tab(text: 'Parent (Code)'),
                      Tab(text: 'Counsellor'),
                      Tab(text: 'Admin'),
                    ],
                  ),
                  const SizedBox(height: 20),

                  if (_errorMessage.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Text(
                        _errorMessage,
                        style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                      ),
                    ),

                  SizedBox(
                    height: 310,
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        // Tab 1: Student
                        _buildStudentTab(),

                        // Tab 2: Parent with Access Code
                        _buildParentTab(),

                        // Tab 3: Counsellor
                        _buildCounsellorTab(),

                        // Tab 4: Admin
                        _buildAdminTab(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStudentTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ChoiceChip(
              label: const Text('Login'),
              selected: !_isRegister,
              onSelected: (val) => setState(() => _isRegister = false),
            ),
            const SizedBox(width: 12),
            ChoiceChip(
              label: const Text('New Student Registration'),
              selected: _isRegister,
              onSelected: (val) => setState(() => _isRegister = true),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_isRegister)
          TextField(
            controller: _studentNameController,
            decoration: const InputDecoration(
              labelText: 'Student Full Name',
              prefixIcon: Icon(Icons.person, size: 20),
              isDense: true,
              border: OutlineInputBorder(),
            ),
          ),
        if (_isRegister) const SizedBox(height: 10),
        TextField(
          controller: _studentPhoneController,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Mobile Number',
            prefixIcon: Icon(Icons.phone, size: 20),
            isDense: true,
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _studentPasswordController,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Password',
            prefixIcon: Icon(Icons.lock, size: 20),
            isDense: true,
            border: OutlineInputBorder(),
          ),
        ),
        const Spacer(),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1B365D),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: _handleStudentAuth,
          child: Text(_isRegister ? 'Register & Generate Parent Code' : 'Sign In as Student'),
        ),
      ],
    );
  }

  Widget _buildParentTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.amber.shade300),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, size: 18, color: Colors.amber),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Enter the Parent Access Code provided by your student to review their career roadmap.',
                  style: TextStyle(fontSize: 11),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _parentCodeController,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: 'Parent Access Code (e.g. SP-7K3M-9QX2)',
            prefixIcon: Icon(Icons.vpn_key, size: 20),
            isDense: true,
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _parentNameController,
          decoration: const InputDecoration(
            labelText: 'Parent / Guardian Name',
            prefixIcon: Icon(Icons.family_restroom, size: 20),
            isDense: true,
            border: OutlineInputBorder(),
          ),
        ),
        const Spacer(),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF8B0000), // Distinct Parent color
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: _handleParentAuth,
          child: const Text('Access Student Portfolio as Parent'),
        ),
      ],
    );
  }

  Widget _buildCounsellorTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Certified Human Counsellor Login',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _counsellorIdController,
          decoration: const InputDecoration(
            labelText: 'Counsellor ID / Email',
            prefixIcon: Icon(Icons.badge, size: 20),
            isDense: true,
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _counsellorPinController,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Security PIN',
            prefixIcon: Icon(Icons.lock, size: 20),
            isDense: true,
            border: OutlineInputBorder(),
          ),
        ),
        const Spacer(),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal.shade800,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          onPressed: _handleCounsellorAuth,
          child: const Text('Open Counsellor Escalation Desk'),
        ),
      ],
    );
  }

  void _handleCounsellorAuth() async {
    setState(() => _errorMessage = '');
    try {
      final session = await _authService.loginCounsellor(
        counsellorId: _counsellorIdController.text.trim(),
        pin: _counsellorPinController.text.trim(),
      );
      if (session != null) {
        widget.onLoginSuccess(session);
      } else {
        setState(() => _errorMessage = 'Invalid counsellor credentials');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Counsellor login failed: $e');
    }
  }

  Widget _buildAdminTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'MSDE Administrator Dashboard Login',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _adminEmailController,
          decoration: const InputDecoration(
            labelText: 'Admin Email (admin@example.com)',
            prefixIcon: Icon(Icons.admin_panel_settings, size: 20),
            isDense: true,
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _adminPasswordController,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Password',
            prefixIcon: Icon(Icons.lock, size: 20),
            isDense: true,
            border: OutlineInputBorder(),
          ),
        ),
        const Spacer(),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.indigo.shade900,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          onPressed: _handleAdminAuth,
          child: const Text('Sign In to MSDE Analytics & AI Hub'),
        ),
      ],
    );
  }

  void _handleAdminAuth() async {
    setState(() => _errorMessage = '');
    try {
      final session = await _authService.loginAdmin(
        email: _adminEmailController.text.trim(),
        password: _adminPasswordController.text.trim(),
      );
      if (session != null) {
        widget.onLoginSuccess(session);
      } else {
        setState(() => _errorMessage = 'Invalid admin credentials');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Admin login failed: $e');
    }
  }
}
