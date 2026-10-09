import {
  classifyConcern,
  toolRetrieveEvidence,
  recommendTrades,
  comparePathways,
  getPathway,
  updateConcernStatus,
  createEscalation,
  generateFamilySummary,
} from './tools';
import { retrieveEvidence } from '../rag/retrieval';
import { runRAGPipeline } from '../rag/verification';
import { generateJSON } from '../gemini';

export interface AgentTurnRequest {
  sessionId: string;
  userMessage: string;
  profile?: any;
  language?: 'en' | 'mr';
}

export interface AgentTurnResponse {
  answer: string;
  citations: string[];
  concernCategory?: string;
  grounded: boolean;
  escalated: boolean;
  toolCallsCount: number;
}

export async function runCounsellorAgent(req: AgentTurnRequest): Promise<AgentTurnResponse> {
  const { sessionId, userMessage, profile = {}, language = 'en' } = req;
  const userTextLower = userMessage.toLowerCase();

  // Safety Rule 1: Check for human counsellor request explicitly
  if (/counsellor|human|talk to person|समुपदेशक|माणूस/.test(userTextLower)) {
    await createEscalation(sessionId, 'User requested human counsellor');
    return {
      answer: language === 'mr'
        ? 'मी तुमच्या विनंतीची नोंद घेतली आहे. मानव समुपदेशक लवकरच तुमच्याशी संपर्क साधेल.'
        : 'I have recorded your request for a human counsellor. A qualified counsellor will connect with your family.',
      citations: [],
      grounded: true,
      escalated: true,
      toolCallsCount: 1,
    };
  }

  // Safety Rule 2: Check for safety or social perception topics (no verified numerical data available)
  if (/safe|danger|accident|surroundings|सुरक्षा/.test(userTextLower) || /respect|society|relatives|status|प्रतिष्ठा|समाज/.test(userTextLower)) {
    const category = /safe|danger|accident|सुरक्षा/.test(userTextLower) ? 'safety' : 'social';
    await updateConcernStatus(sessionId, category, 'escalated');
    await createEscalation(sessionId, `Topic '${category}' has no verified outcome numerical dataset.`);

    return {
      answer: language === 'mr'
        ? `आम्हाकडे या विषयावर (सुरक्षा / सामाजिक प्रतिष्ठा) अद्याप सत्यापित संख्यात्मक डेटा उपलब्ध नाही.\nमानव समुपदेशक यावर आपल्या कुटुंबाशी चर्चा करू शकतात.`
        : `We do not have verified outcome numerical dataset on this specific topic (${category}).\nA human counsellor can discuss this with your family.`,
      citations: [],
      concernCategory: category,
      grounded: false,
      escalated: true,
      toolCallsCount: 1,
    };
  }

  // Classify concern
  const classification = await classifyConcern(userMessage);
  const primaryCategory = classification.categories[0] || 'job';

  // Mark concern as raised in session
  await updateConcernStatus(sessionId, primaryCategory, 'raised');

  // Retrieve evidence using RAG
  const trade = profile.trade || profile.sInterestTrade || 'Electrician';
  const location = profile.sLoc || 'Nagpur';

  const retrieved = await retrieveEvidence(userMessage, trade, location);
  const ragResult = await runRAGPipeline(userMessage, retrieved.chunks, language, sessionId, trade, location);

  if (!ragResult.grounded || ragResult.escalated) {
    await updateConcernStatus(sessionId, primaryCategory, 'escalated');
    await createEscalation(sessionId, `Verified data missing for trade: ${trade}, location: ${location}, question: "${userMessage}"`);
  } else {
    await updateConcernStatus(sessionId, primaryCategory, 'answered', { citations: ragResult.citations });
  }

  return {
    answer: ragResult.answer,
    citations: ragResult.citations,
    concernCategory: primaryCategory,
    grounded: ragResult.grounded,
    escalated: ragResult.escalated,
    toolCallsCount: 2,
  };
}
