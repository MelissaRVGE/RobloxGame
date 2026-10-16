// Рендер svg/*.svg -> png/*.png 256x256 через Chromium (Playwright). Другие папки: node render.js <svg> <png>
const { chromium } = require('playwright');
const fs = require('fs'), path = require('path');
(async () => {
  const dir = path.join(__dirname, process.argv[2] || 'svg'), out = path.join(__dirname, process.argv[3] || 'png');
  fs.mkdirSync(out, { recursive: true });
  const browser = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium', headless: true }).catch(() => chromium.launch());
  const page = await browser.newPage({ viewport: { width: 512, height: 512 }, deviceScaleFactor: 0.5 });
  for (const f of fs.readdirSync(dir).filter(f => f.endsWith('.svg')).sort()) {
    await page.setContent(`<html><body style="margin:0;background:transparent">${fs.readFileSync(path.join(dir, f), 'utf8')}</body></html>`);
    await page.waitForTimeout(150);
    fs.writeFileSync(path.join(out, f.replace('.svg', '.png')), await page.screenshot({ omitBackground: true, clip: { x: 0, y: 0, width: 512, height: 512 } }));
  }
  await browser.close();
  console.log('rendered');
})();
