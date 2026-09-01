const puppeteer = require('puppeteer');
const PuppeteerHar = require('puppeteer-har');
const path = require('path');
const mkdirp = require('mkdirp');
const os = require('os');

(async () => {
  const HAR_DIR = path.join(os.homedir(), 'har_logs');
  mkdirp.sync(HAR_DIR);

  const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
  const harPath = path.join(HAR_DIR, `log_${timestamp}.har`);

  console.log("🚀 Iniciando navegador com Chrome do sistema...");
  const browser = await puppeteer.launch({
    headless: false,
    executablePath: '/usr/bin/google-chrome-stable', // Altere se necessário
    args: [
      '--no-sandbox',
      '--disable-setuid-sandbox',
      '--autoplay-policy=no-user-gesture-required'

    ]
  });

  try {
    const context = browser.defaultBrowserContext();
    const page = await context.newPage();
    const har = new PuppeteerHar(page);

    console.log("🌐 Acessando: http://172.31.0.51");
    await har.start({ path: harPath });

    await page.goto('http://172.31.0.51', { waitUntil: 'domcontentloaded', timeout: 30000 });
    console.log("✅ Página carregada.");

    await page.waitForSelector('video', { timeout: 15000 });
    console.log("🎬 Player de vídeo detectado!");

    await page.evaluate(() => {
      const video = document.querySelector('video');
      if (video) {
        video.muted = true;
        video.play();
      }
    });

    console.log("⏳ Capturando tráfego por 3 minutos...");
    await new Promise(resolve => setTimeout(resolve, 180000));

    await har.stop();
    console.log(`✅ HAR salvo em: ${harPath}`);
  } catch (err) {
    console.error("❌ Erro durante a execução:", err.message || err);
  } finally {
    await browser.close();
    console.log("👋 Navegador fechado.");
  }
})();
