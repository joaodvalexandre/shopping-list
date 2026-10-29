// Renders the SVG sources to PNG with headless Chrome (transparent where the SVG is).
// usage: node render.mjs   (from this folder; Chrome at the default Windows path)
import { spawnSync } from 'node:child_process';
import { copyFileSync, mkdirSync, mkdtempSync, readFileSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

const chrome = process.env.CHROME ?? 'C:/Program Files/Google/Chrome/Application/chrome.exe';

export function render(svgPath, pngPath, size) {
  const svg = readFileSync(svgPath, 'utf8');
  const dir = mkdtempSync(join(tmpdir(), 'icon-'));
  const html = join(dir, 'page.html');
  writeFileSync(html, `<!doctype html><style>html,body{margin:0;background:transparent}svg{display:block;width:${size}px;height:${size}px}</style>${svg}`);
  mkdirSync(resolve(pngPath, '..'), { recursive: true });
  const result = spawnSync(chrome, [
    '--headless=new', '--disable-gpu', '--hide-scrollbars', '--default-background-color=00000000',
    `--window-size=${size},${size}`, `--screenshot=${resolve(pngPath)}`, pathToFileURL(html).href,
  ], { stdio: 'ignore' });
  if (result.status !== 0) throw new Error(`Chrome failed for ${pngPath}`);
}

/** A .ico holding PNG images of the given sizes. */
function writeIco(path, sizes) {
  const images = sizes.map((size) => {
    const png = join(mkdtempSync(join(tmpdir(), 'ico-')), `${size}.png`);
    render('icon.svg', png, size);
    return { size, data: readFileSync(png) };
  });

  const header = Buffer.alloc(6 + 16 * images.length);
  header.writeUInt16LE(1, 2);                 // type: icon
  header.writeUInt16LE(images.length, 4);

  let offset = header.length;
  images.forEach(({ size, data }, i) => {
    const entry = 6 + 16 * i;
    header.writeUInt8(size, entry);           // width
    header.writeUInt8(size, entry + 1);       // height
    header.writeUInt16LE(1, entry + 4);       // colour planes
    header.writeUInt16LE(32, entry + 6);      // bits per pixel
    header.writeUInt32LE(data.length, entry + 8);
    header.writeUInt32LE(offset, entry + 12);
    offset += data.length;
  });

  writeFileSync(path, Buffer.concat([header, ...images.map((image) => image.data)]));
}

if (process.argv[1] && pathToFileURL(resolve(process.argv[1])).href === import.meta.url) {
  render('icon.svg', 'icon.png', 1024);
  render('icon_foreground.svg', 'icon_foreground.png', 1024);
  render('icon_monochrome.svg', 'icon_monochrome.png', 1024);
  render('icon.svg', 'logo.png', 256);

  // The small icon of notifications (Android only uses its shape), in each density
  const res = resolve('../../android/app/src/main/res');
  for (const [density, size] of [['mdpi', 24], ['hdpi', 36], ['xhdpi', 48], ['xxhdpi', 72], ['xxxhdpi', 96]]) {
    render('icon_monochrome.svg', join(res, `drawable-${density}/ic_stat_notify.png`), size);
  }

  // The web app's copies, in its public folder
  const publicDir = resolve('../../../../public');
  copyFileSync('icon.svg', join(publicDir, 'img/logo.svg'));
  render('icon.svg', join(publicDir, 'img/icon-192.png'), 192);
  render('icon.svg', join(publicDir, 'img/icon-512.png'), 512);
  render('icon.svg', join(publicDir, 'img/apple-touch-icon.png'), 180);
  writeIco(join(publicDir, 'favicon.ico'), [16, 32, 48]);
  console.log('rendered');
}
