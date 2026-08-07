import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const projectRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const source = readFileSync(path.join(projectRoot, 'ACO.svg'), 'utf8');
const outputRoot = path.join(projectRoot, 'assets', 'design_svg', 'source', 'images');

function attribute(markup, name) {
  const prefix = `${name}="`;
  const start = markup.indexOf(prefix);
  if (start < 0) return '';
  const valueStart = start + prefix.length;
  return markup.slice(valueStart, markup.indexOf('"', valueStart));
}

mkdirSync(outputRoot, { recursive: true });
let count = 0;
for (const chunk of source.split('<image ').slice(1)) {
  const markup = chunk.slice(0, chunk.indexOf('/>') + 2);
  const id = attribute(markup, 'id');
  const href = attribute(markup, 'href');
  const match = href.match(/^data:image\/([^;]+);base64,(.*)$/s);
  if (id === '' || match == null) continue;
  const extension = match[1] === 'jpeg' ? 'jpg' : match[1];
  writeFileSync(path.join(outputRoot, `${id}.${extension}`), Buffer.from(match[2], 'base64'));
  count += 1;
}

console.log(`Extracted ${count} original embedded image assets to ${outputRoot}.`);
