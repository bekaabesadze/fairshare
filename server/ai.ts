import Anthropic from '@anthropic-ai/sdk';
import type { AppState, AssistantMessage, AssistantReply } from '../shared/types.ts';
import { buildContext, knowledgeText, localAnswer, SYSTEM_PROMPT } from '../shared/assistant.ts';

const wantsClaude =
  process.env.FAIRSHARE_AI !== 'local' &&
  Boolean(process.env.ANTHROPIC_API_KEY || process.env.ANTHROPIC_AUTH_TOKEN || process.env.FAIRSHARE_AI === 'claude');

let client: Anthropic | null = null;
let disabledReason: string | null = wantsClaude ? null : 'no credentials configured';

export const aiStatus = () => ({ engine: disabledReason ? 'local' : 'claude', reason: disabledReason });

export async function answer(state: AppState, orgId: string, messages: AssistantMessage[], today: string): Promise<AssistantReply> {
  const question = messages[messages.length - 1]?.text ?? '';
  const local = localAnswer(state, orgId, question, today, messages);
  if (disabledReason || !state.institution.aiEnabled) return local;

  try {
    client ??= new Anthropic({ timeout: 25_000, maxRetries: 1 });
    const system = `${SYSTEM_PROMPT}\n\n# Organization data\n${buildContext(state, orgId, today)}\n\n# Luther knowledge base\n${knowledgeText()}`;
    const response = await client.beta.messages.create({
      model: 'claude-opus-5-5',
      max_tokens: 16000,
      betas: ['server-side-fallback-2026-07-01'],
      fallbacks: 'default',
      output_config: { effort: 'low' },
      system,
      messages: messages.slice(-12).map((m) => ({ role: m.role, content: m.text })),
    } as Anthropic.Beta.Messages.MessageCreateParamsNonStreaming);

    if (response.stop_reason === 'refusal') return local;
    const text = response.content
      .map((b) => (b.type === 'text' ? b.text : ''))
      .join('')
      .trim();
    if (!text) return local;
    return { ...local, text, engine: 'claude', sources: local.sources.length ? local.sources : ['Your budget'] };
  } catch (error) {
    if (error instanceof Anthropic.AuthenticationError || error instanceof Anthropic.PermissionDeniedError) {
      disabledReason = 'credentials rejected';
    } else if (error instanceof Anthropic.APIError) {
      console.warn(`[ai] Claude API error ${error.status}: ${error.message} — answering locally`);
    } else {
      console.warn('[ai] Claude unavailable — answering locally:', (error as Error).message);
    }
    return local;
  }
}
