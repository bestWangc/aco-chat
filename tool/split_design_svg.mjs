import { createHash } from 'node:crypto';
import { cpSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const projectRoot = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  '..',
);
const sourcePath = path.join(projectRoot, 'ACO.svg');
const designRoot = path.join(projectRoot, 'assets', 'design_svg');
const outputRoot = path.join(designRoot, 'v2');
const sourceOutput = path.join(designRoot, 'source', 'aco_v2.svg');

// The canvas has no useful artboard labels, so this table gives every export a
// stable feature path while retaining the source-board number in index.json.
const screens = [
  ['wallet', 'chain-list', 'light', 1],
  ['dex', 'token-overview', 'light', 2],
  ['wallet', 'add-token-v1', 'light', 3],
  ['browser', 'discover', 'light', 4],
  ['social', 'live-stream', 'dark', 5],
  ['social', 'live-stream', 'light', 6],
  ['message', 'chat-list', 'dark', 7],
  ['message', 'chat-list', 'light', 8],
  ['dex', 'swap', 'light', 9],
  ['dex', 'swap', 'dark', 10],
  ['browser', 'discover', 'dark', 11],
  ['wallet', 'asset-detail', 'light', 12],
  ['wallet', 'asset-detail', 'dark', 13],
  ['wallet', 'receive', 'light', 14],
  ['wallet', 'receive', 'dark', 15],
  ['wallet', 'add-token-v2', 'light', 16],
  ['wallet', 'add-token-v2', 'dark', 17],
  ['account', 'profile-overview', 'light', 18],
  ['account', 'profile-overview', 'dark', 19],
  ['message', 'conversation-v1', 'light', 20],
  ['message', 'conversation-v1', 'dark', 21],
  ['message', 'conversation-v2', 'dark', 22],
  ['message', 'conversation-v2', 'light', 23],
  ['mining', 'mining-overview', 'light', 24],
  ['mining', 'mining-overview', 'dark', 25],
  ['wallet', 'chain-list', 'dark', 26],
  ['dex', 'token-overview', 'dark', 27],
  ['wallet', 'add-token-v1', 'dark', 28],
  ['wallet', 'home', 'dark', 29],
  ['wallet', 'home', 'light', 30],
  ['market', 'overview', 'dark', 31],
  ['square', 'feed', 'light', 32],
  ['square', 'feed', 'dark', 33],
  ['market', 'overview', 'light', 34],
  ['social', 'voice-room', 'light', 35],
  ['social', 'voice-room', 'dark', 36],
].map(([feature, screen, theme, board]) => ({ feature, screen, theme, board }));

function parseArtboards(svg) {
  const artboards = svg.match(/<g id="_Artboards_">([\s\S]*?)<\/g>/)?.[1];
  if (artboards == null) throw new Error('Unable to find the exported artboards.');

  return [...artboards.matchAll(
    /<path[^>]*id="([^"]+)"[^>]*d="m([\d.-]+) ([\d.-]+)h([\d.-]+)v-([\d.-]+)h-([\d.-]+)z"\/>/g,
  )].map((match, index) => ({
    board: index + 1,
    sourceName: match[1],
    x: Number(match[2]),
    y: Number(match[3]) - Number(match[5]),
    width: Number(match[4]),
    height: Number(match[5]),
  }));
}

function extractImages(defs) {
  return [...defs.matchAll(/<image\b[\s\S]*?\/>/g)].map((match) => {
    const id = match[0].match(/\bid="([^"]+)"/)?.[1];
    const width = Number(match[0].match(/\bwidth="([\d.]+)"/)?.[1]);
    const height = Number(match[0].match(/\bheight="([\d.]+)"/)?.[1]);
    if (id == null || !Number.isFinite(width) || !Number.isFinite(height)) {
      throw new Error('Unable to read an embedded image definition.');
    }
    return { id, width, height, markup: match[0] };
  });
}

function parseImageUses(body) {
  return [...body.matchAll(/<use\b[^>]*\bhref="#([^"]+)"[^>]*\/>/g)].flatMap((match) => {
    const transform = match[0].match(/\btransform="matrix\(([^)]+)\)"/)?.[1];
    if (transform == null) return [];
    const values = transform.split(',').map(Number);
    if (values.length !== 6 || values.some(Number.isNaN)) return [];
    return [{ id: match[1], scaleX: values[0], scaleY: values[3], x: values[4], y: values[5] }];
  });
}

function overlaps(rect, imageUse, definition) {
  const right = imageUse.x + Math.abs(imageUse.scaleX) * definition.width;
  const bottom = imageUse.y + Math.abs(imageUse.scaleY) * definition.height;
  return (
    imageUse.x < rect.x + rect.width &&
    right > rect.x &&
    imageUse.y < rect.y + rect.height &&
    bottom > rect.y
  );
}

const source = readFileSync(sourcePath, 'utf8');
const defs = source.match(/<defs>[\s\S]*?<\/defs>/)?.[0];
if (defs == null) throw new Error('Unable to find SVG definitions.');

const bodyStart = source.indexOf('</defs>') + '</defs>'.length;
const bodyEnd = source.lastIndexOf('</svg>');
const body = source.slice(bodyStart, bodyEnd);
const artboards = parseArtboards(source);
const images = extractImages(defs);
const imageById = new Map(images.map((image) => [image.id, image]));
const imageUses = parseImageUses(body);
const sharedDefs = defs
  .replace(/^<defs>/, '')
  .replace(/<\/defs>$/, '')
  .replace(/<image\b[\s\S]*?\/>/g, '');
const sourceHash = createHash('sha256').update(source).digest('hex');

if (artboards.length !== screens.length) {
  throw new Error(`Expected ${screens.length} artboards but found ${artboards.length}.`);
}

rmSync(outputRoot, { recursive: true, force: true });
mkdirSync(outputRoot, { recursive: true });
mkdirSync(path.dirname(sourceOutput), { recursive: true });
cpSync(sourcePath, sourceOutput);

const index = screens.map((screen) => {
  const rect = artboards.find((artboard) => artboard.board === screen.board);
  const imageMarkup = imageUses
    .filter((imageUse) => {
      const definition = imageById.get(imageUse.id);
      return definition != null && overlaps(rect, imageUse, definition);
    })
    .map((imageUse) => imageById.get(imageUse.id).markup)
    .filter((markup, index, values) => values.indexOf(markup) === index)
    .join('\n');
  const relativePath = path.posix.join(
    'v2',
    screen.feature,
    screen.theme,
    `${screen.screen}.svg`,
  );
  const absolutePath = path.join(designRoot, relativePath);
  const pageSvg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="${rect.x} ${rect.y} ${rect.width} ${rect.height}" width="${rect.width}" height="${rect.height}">\n<defs>\n${sharedDefs}\n${imageMarkup}\n</defs>${body}</svg>\n`;

  mkdirSync(path.dirname(absolutePath), { recursive: true });
  writeFileSync(absolutePath, pageSvg);

  return {
    ...screen,
    asset: `assets/design_svg/${relativePath}`,
    sourceRect: {
      x: rect.x,
      y: rect.y,
      width: rect.width,
      height: rect.height,
    },
    sourceName: rect.sourceName,
  };
});

writeFileSync(
  path.join(outputRoot, 'index.json'),
  `${JSON.stringify({ source: 'assets/design_svg/source/aco_v2.svg', sourceHash, pages: index }, null, 2)}\n`,
);

console.log(`Exported ${index.length} categorized artboards from ${sourcePath}.`);
