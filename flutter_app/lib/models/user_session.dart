import 'dart:math';

class StudentProfile {
  String name;
  String education;
  String location;
  String interest;
  String duration;
  String goal;
  String selectedTrade;

  StudentProfile({
    this.name = 'Aarav Sharma',
    this.education = '10th Pass',
    this.location = 'Nagpur',
    this.interest = 'Electrical / Technology',
    this.duration = '12 Months',
    this.goal = 'Steady employment in electrical sector',
    this.selectedTrade = 'Electrician',
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'education': education,
    'location': location,
    'interest': interest,
    'duration': duration,
    'goal': goal,
    'selectedTrade': selectedTrade,
  };
}

class FamilyContext {
  String incomeBracket;
  String stability;
  String educationAttitude;
  String locationRequirement;
  List<String> activeConcerns;

  FamilyContext({
    this.incomeBracket = '₹10,000 - ₹20,000 / month',
    this.stability = 'Private company employment',
    this.educationAttitude = 'Skill certification is acceptable',
    this.locationRequirement = 'Prefer staying in home district',
    this.activeConcerns = const ['income', 'job'],
  });

  Map<String, dynamic> toJson() => {
    'incomeBracket': incomeBracket,
    'stability': stability,
    'educationAttitude': educationAttitude,
    'locationRequirement': locationRequirement,
    'activeConcerns': activeConcerns,
  };
}

class UserSession {
  final String sessionId;
  final String studentPhone;
  String parentAccessCode;
  String studentName;
  String parentName;
  String role; // 'student' | 'parent' | 'admin' | 'counsellor'
  StudentProfile profile;
  FamilyContext familyContext;
  Map<String, String> concernFeedback; // concern_id -> 'resolved' | 'partly' | 'unresolved'
  List<String> counsellorNotes;

  UserSession({
    required this.sessionId,
    required this.studentPhone,
    required this.parentAccessCode,
    this.studentName = 'Aarav Sharma',
    this.parentName = 'Rajesh Sharma',
    this.role = 'student',
    StudentProfile? profile,
    FamilyContext? familyContext,
    Map<String, String>? concernFeedback,
    List<String>? counsellorNotes,
  })  : profile = profile ?? StudentProfile(),
        familyContext = familyContext ?? FamilyContext(),
        concernFeedback = concernFeedback ?? {},
        counsellorNotes = counsellorNotes ?? [];

  static String generateParentAccessCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random();
    String part1 = List.generate(4, (_) => chars[random.nextInt(chars.length)]).join();
    String part2 = List.generate(4, (_) => chars[random.nextInt(chars.length)]).join();
    return 'SP-$part1-$part2';
  }

  void regenerateParentCode() {
    parentAccessCode = generateParentAccessCode();
  }
}
