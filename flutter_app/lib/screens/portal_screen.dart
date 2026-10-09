import 'package:flutter/material.dart';
import '../models/user_session.dart';
import '../widgets/government_header.dart';
import '../widgets/step_progress_bar.dart';
import '../widgets/ai_counsellor_bottom_sheet.dart';
import 'admin_screen.dart';
import 'counsellor_screen.dart';
import 'steps/step1_profile_view.dart';
import 'steps/step2_context_view.dart';
import 'steps/step3_outcomes_view.dart';
import 'steps/step4_concerns_view.dart';
import 'steps/step5_pathway_view.dart';
import 'steps/step6_summary_view.dart';
import 'steps/step7_counsellor_view.dart';

class PortalScreen extends StatefulWidget {
  final UserSession session;
  final VoidCallback onLogout;

  const PortalScreen({
    Key? key,
    required this.session,
    required this.onLogout,
  }) : super(key: key);

  @override
  State<PortalScreen> createState() => _PortalScreenState();
}

class _PortalScreenState extends State<PortalScreen> {
  String _lang = 'en';
  int _currentStep = 0;
  int _maxUnlockedStep = 0;

  void _onStepSelected(int step) {
    setState(() {
      _currentStep = step;
    });
  }

  void _nextStep() {
    setState(() {
      if (_currentStep < 6) {
        _currentStep++;
        if (_currentStep > _maxUnlockedStep) {
          _maxUnlockedStep = _currentStep;
        }
      }
    });
  }

  void _prevStep() {
    setState(() {
      if (_currentStep > 0) {
        _currentStep--;
      }
    });
  }

  void _openAiBot() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AiCounsellorBottomSheet(
        lang: _lang,
        role: widget.session.role,
        activeTrade: widget.session.profile.selectedTrade,
        activeLocation: widget.session.profile.location,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.session.role == 'admin') {
      return Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: GovernmentHeader(
            currentLang: _lang,
            onLanguageChanged: (l) => setState(() => _lang = l),
            onLogout: widget.onLogout,
          ),
        ),
        body: AdminScreen(onBack: widget.onLogout),
      );
    }

    if (widget.session.role == 'counsellor') {
      return Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: GovernmentHeader(
            currentLang: _lang,
            onLanguageChanged: (l) => setState(() => _lang = l),
            onLogout: widget.onLogout,
          ),
        ),
        body: CounsellorScreen(onBack: widget.onLogout),
      );
    }

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: GovernmentHeader(
          currentLang: _lang,
          onLanguageChanged: (l) => setState(() => _lang = l),
          onLogout: widget.onLogout,
        ),
      ),
      body: Column(
        children: [
          // 7-Step Navigation Indicator
          StepProgressBar(
            currentStep: _currentStep,
            maxUnlockedStep: _maxUnlockedStep,
            lang: _lang,
            onStepSelected: _onStepSelected,
          ),
          const Divider(height: 1),

          // Active Step View
          Expanded(
            child: _buildCurrentStepView(),
          ),
        ],
      ),

      // Floating AI Career Counsellor Button
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF1B365D),
        icon: const Icon(Icons.psychology, color: Color(0xFFFF9933)),
        label: Text(
          _lang == 'mr' ? 'AI समुपदेशक (Gemini)' : 'Ask AI Counsellor',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        onPressed: _openAiBot,
      ),
    );
  }

  Widget _buildCurrentStepView() {
    switch (_currentStep) {
      case 0:
        return Step1ProfileView(
          session: widget.session,
          lang: _lang,
          onNext: _nextStep,
        );
      case 1:
        return Step2ContextView(
          session: widget.session,
          lang: _lang,
          onNext: _nextStep,
          onBack: _prevStep,
        );
      case 2:
        return Step3OutcomesView(
          session: widget.session,
          lang: _lang,
          onNext: _nextStep,
          onBack: _prevStep,
        );
      case 3:
        return Step4ConcernsView(
          session: widget.session,
          lang: _lang,
          onNext: _nextStep,
          onBack: _prevStep,
        );
      case 4:
        return Step5PathwayView(
          session: widget.session,
          lang: _lang,
          onNext: _nextStep,
          onBack: _prevStep,
        );
      case 5:
        return Step6SummaryView(
          session: widget.session,
          lang: _lang,
          onNext: _nextStep,
          onBack: _prevStep,
        );
      case 6:
        return Step7CounsellorView(
          session: widget.session,
          lang: _lang,
          onBack: _prevStep,
        );
      default:
        return const SizedBox();
    }
  }
}
