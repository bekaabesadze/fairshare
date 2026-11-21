import { createWorker, type Worker } from 'tesseract.js';
import { parseDocument, type ParsedDocument } from '../../../shared/ocr-parse.ts';
import type { DocType } from '../../../shared/types.ts';

let workerPromise: Promise<Worker> | null = null;
let onProgress: ((p: number, status: string) => void) | null = null;

function getWorker() {
  workerPromise ??= createWorker('eng', 1, {
    workerPath: '/ocr/worker.min.js',
    corePath: `${location.origin}/ocr`,
    langPath: `${location.origin}/ocr`,
    gzip: true,
    logger: (m: { status: string; progress: number }) => onProgress?.(m.progress, m.status),
  });
  return workerPromise;
}

export function warmOcr() {
  getWorker().catch(() => {
    workerPromise = null;
  });
}

export interface ScanResult {
  text: string;
  confidence: number;
  parsed: ParsedDocument;
}

export async function scanDocument(image: string, forced: DocType | undefined, progress?: (p: number, status: string) => void): Promise<ScanResult> {
  onProgress = progress ?? null;
  const worker = await getWorker();
  const { data } = await worker.recognize(image);
  onProgress = null;
  return { text: data.text, confidence: data.confidence, parsed: parseDocument(data.text, forced) };
}
