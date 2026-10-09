class AppConstants {
  // Provided Gemini API Key & Model
  static const String geminiApiKey = 'AIzaSyBHIKQFVnKcVllZKbk9d-hOUuNsgN7PNpk';
  static const String geminiModel = 'gemini-3.8-flash';
  static const String geminiApiEndpoint = 'https://generativelanguage.googleapis.com/v1beta/models';

  // Concerns list
  static const List<Map<String, String>> concerns = [
    {
      'id': 'income',
      'icon': '💰',
      'title_en': 'Income & Earnings',
      'title_mr': 'कमाई आणि उत्पन्न',
      'desc': 'Starting salary, progression over 3-5 years, and return on training investment.'
    },
    {
      'id': 'job',
      'icon': '🏢',
      'title_en': 'Job Security & Placement',
      'title_mr': 'नोकरी आणि स्थान',
      'desc': 'Verified placement rates, employer partnerships, and formal contract security.'
    },
    {
      'id': 'social',
      'icon': '👪',
      'title_en': 'Social Perception & Respect',
      'title_mr': 'समाजातील प्रतिष्ठा',
      'desc': 'Dignity of technical skills, societal respect, and modern technological identity.'
    },
    {
      'id': 'growth',
      'icon': '📈',
      'title_en': 'Career Growth & Promotion',
      'title_mr': 'करिअर प्रगती',
      'desc': 'Supervisor roles, technician certification, and entrepreneurial pathways.'
    },
    {
      'id': 'safety',
      'icon': '🛡️',
      'title_en': 'Workplace Safety',
      'title_mr': 'कामाचे ठिकाण सुरक्षा',
      'desc': 'OSHA & Indian safety standards, protective gear, and regulated environments.'
    },
    {
      'id': 'edu',
      'icon': '🎓',
      'title_en': 'Further Education & Lateral Entry',
      'title_mr': 'पुढील शिक्षण',
      'desc': 'Lateral entry to Polytechnic Diploma and B.Tech / B.Voc degrees.'
    },
    {
      'id': 'cost',
      'icon': '🧾',
      'title_en': 'Training Cost & Subsidies',
      'title_mr': 'प्रशिक्षण खर्च',
      'desc': 'Government subsidies, fee structures, and post-placement payback period.'
    },
    {
      'id': 'localjobs',
      'icon': '📍',
      'title_en': 'Local Jobs in District',
      'title_mr': 'स्थानिक नोकऱ्या',
      'desc': 'District-level employment opportunities avoiding unwanted relocation.'
    },
  ];

  static const Map<String, Map<String, String>> i18n = {
    'en': {
      'portal_title': 'SkillPath Family Counselling Portal',
      'portal_sub': 'Ministry of Skill Development & Entrepreneurship Support Platform',
      'nav_step1': 'Profile',
      'nav_step2': 'Context',
      'nav_step3': 'Outcomes',
      'nav_step4': 'Concerns',
      'nav_step5': 'Pathway',
      'nav_step6': 'Decision',
      'nav_step7': 'Counsellor',
      'parent_code_label': 'Parent Access Code',
      'copy': 'Copy',
      'verified_badge': 'Verified Govt Data',
      'ask_ai': 'Ask AI Counsellor',
      'send': 'Send',
      'speak': 'Read Aloud',
      'speech_input': 'Speak Query',
      'submit': 'Save & Proceed',
    },
    'mr': {
      'portal_title': 'स्किलपाथ कौटुंबिक समुपदेशन पोर्टल',
      'portal_sub': 'कौशल्य विकास आणि उद्योजकता मंत्रालय सहाय्य व्यासपीठ',
      'nav_step1': 'माहिती',
      'nav_step2': 'कुटुंब',
      'nav_step3': 'परिणाम',
      'nav_step4': 'शंका निवारण',
      'nav_step5': 'मार्ग',
      'nav_step6': 'निर्णय',
      'nav_step7': 'समुपदेशक',
      'parent_code_label': 'पालक प्रवेश कोड',
      'copy': 'कॉपी करा',
      'verified_badge': 'सत्यापित शासकीय माहिती',
      'ask_ai': 'AI समुपदेशकाला विचारा',
      'send': 'पाठवा',
      'speak': 'मोठ्याने वाचा',
      'speech_input': 'बोला',
      'submit': 'जतन करा आणि पुढे चला',
    }
  };
}
