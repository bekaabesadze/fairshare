import Tesseract from 'tesseract.js';
const { createWorker } = Tesseract;
import { fileURLToPath } from 'node:url';
import { parseDocument, detectDocType } from '../../shared/ocr-parse.ts';
const root = fileURLToPath(new URL('../../web/public', import.meta.url));
const fixtures = fileURLToPath(new URL('./fixtures', import.meta.url));
const worker = await createWorker('eng', 1, { langPath: root + '/ocr', cacheMethod: 'none', gzip: true });
const cases = [
  [`${root}/samples`, 'bookshop'],
  [fixtures, 'pizza'],
  [fixtures, 'docucenter'],
  [`${root}/samples`, 'check-uptous'],
  [fixtures, 'check'],
];
for (const [dir, f] of cases) {
  const t0 = Date.now();
  const { data } = await worker.recognize(`${dir}/${f}.png`);
  const p = parseDocument(data.text);
  console.log(`\n== ${f} (${Date.now()-t0}ms, conf ${Math.round(data.confidence)}) type=${detectDocType(data.text)}`);
  if (f.startsWith('check')) console.log(data.text);
  console.log(JSON.stringify(p));
}
await worker.terminate();
