import fs from 'node:fs';
import { makeSeed } from '../shared/seed.ts';
fs.writeFileSync(new URL('../ios/FairShare/Resources/seed.json', import.meta.url), JSON.stringify(makeSeed(), null, 1));
console.log('wrote ios/FairShare/Resources/seed.json');
