import type { IaAnalyzeScopeType } from './scope.contract';
import type {
  IaAnalyzeAnalyzedItem,
  IaAnalyzeContext,
  IaAnalyzeInsights,
} from './analysis.contract';

/**
 * Contratos da API pública de execução de análise IA.
 * Servem para tipar requisição, resposta e erro do endpoint protegido.
 */
export interface IaAnalyzeRunRequest {
  limit?: number;
  scope_type?: IaAnalyzeScopeType;
  catalog_item_id?: string;
}

export interface IaAnalyzeRunResponse {
  analyzedCount: number;
  feedbacksAnalyzed: IaAnalyzeAnalyzedItem[];
  globalInsights: IaAnalyzeInsights | null;
  contexts: IaAnalyzeContext[];
}

export interface IaAnalyzeRunErrorResponse {
  error: string;
  message?: string;
  issues?: unknown;
}

export interface IaAnalyzeRawRunRequest {
  limit?: number;
  scope_type?: IaAnalyzeScopeType;
  catalog_item_id?: string;
}

export interface IaAnalyzeRawRunResponse {
  analyzedCount: number;
  feedbacksAnalyzed: IaAnalyzeAnalyzedItem[];
}

export interface IaAnalyzeRegenerateInsightsRequest {
  scope_type?: IaAnalyzeScopeType;
  catalog_item_id?: string;
  /**
   * Quando `true`, ignora o cache de leitura e força uma nova geração via LLM,
   * mesmo que já exista relatório salvo e sem feedback novo (botão "forçar
   * regeneração"). Por padrão (`false`/ausente) o cache é respeitado.
   */
  force?: boolean;
}

export interface IaAnalyzeRegenerateInsightsResponse {
  globalInsights: IaAnalyzeInsights | null;
  contexts: IaAnalyzeContext[];
  /**
   * `true` somente quando um relatório foi DE FATO persistido para o escopo
   * pedido (escopo informado: existe relatório salvo para scope_type+item;
   * sem escopo: ao menos um relatório foi salvo). Evita o "falso sucesso":
   * permite ao front avisar honestamente quando nada foi gerado (ex.: escopo
   * sem feedbacks com texto analisados suficientes).
   */
  reportGenerated: boolean;
  /**
   * `true` quando a resposta veio do relatório salvo (cache de leitura), sem
   * chamar o LLM — caso não haja feedback analisado novo desde a última geração.
   * Permite ao front distinguir "recalculado agora" de "reaproveitado".
   */
  fromCache: boolean;
}
