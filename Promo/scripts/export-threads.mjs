/**
 * Export Threads frames (1080×1920 PNG) from the Vite promo deck.
 *
 * Usage: npm run export:threads
 * Output default: agent-store media/promo-threads/
 */
import { chromium } from 'playwright'
import { spawn } from 'node:child_process'
import { mkdir, writeFile } from 'node:fs/promises'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const promoRoot = path.resolve(__dirname, '..')
const defaultOut = '/cursor/stores/bc-c8df8d63-d424-4cfc-a21e-e4b21386f06a/media/promo-threads'
const outDir = process.env.THREADS_OUT || defaultOut
const port = Number(process.env.PROMO_PORT || 47321)
const base = `http://127.0.0.1:${port}/?export=1`

function wait(ms) {
  return new Promise((r) => setTimeout(r, ms))
}

async function waitForServer(url, attempts = 60) {
  for (let i = 0; i < attempts; i++) {
    try {
      const res = await fetch(url)
      if (res.ok) return
    } catch {
      // retry
    }
    await wait(500)
  }
  throw new Error(`Vite not ready at ${url}`)
}

async function main() {
  await mkdir(outDir, { recursive: true })

  const vite = spawn('npx', ['vite', '--host', '127.0.0.1', '--port', String(port), '--strictPort'], {
    cwd: promoRoot,
    stdio: ['ignore', 'pipe', 'pipe'],
    env: { ...process.env },
  })

  let bootLog = ''
  vite.stdout.on('data', (d) => {
    bootLog += d.toString()
  })
  vite.stderr.on('data', (d) => {
    bootLog += d.toString()
  })

  try {
    await waitForServer(base)
    const browser = await chromium.launch({ headless: true })
    const page = await browser.newPage({
      viewport: { width: 1080, height: 1920 },
      deviceScaleFactor: 1,
    })
    await page.goto(base, { waitUntil: 'networkidle' })
    await page.waitForSelector('.frame')

    const files = await page.$$eval('.frame', (nodes) =>
      nodes.map((n) => ({
        id: n.getAttribute('data-frame') || 'frame',
        file: n.getAttribute('data-file') || 'frame.png',
      }))
    )

    const manifest = []
    for (let i = 0; i < files.length; i++) {
      const handle = await page.$(`.frame[data-frame="${files[i].id}"]`)
      if (!handle) throw new Error(`Missing frame ${files[i].id}`)
      const outPath = path.join(outDir, files[i].file)
      await handle.screenshot({ path: outPath, type: 'png' })
      manifest.push({ file: files[i].file, path: outPath })
      console.log(`OK  ${files[i].file}`)
    }

    await writeFile(
      path.join(outDir, 'manifest.json'),
      JSON.stringify({ generatedAt: new Date().toISOString(), frames: manifest }, null, 2)
    )
    await browser.close()
    console.log(`\nExported ${manifest.length} frames → ${outDir}`)
  } finally {
    vite.kill('SIGTERM')
    await wait(300)
    if (!vite.killed) vite.kill('SIGKILL')
    if (bootLog.includes('error')) {
      // keep quiet unless export failed
    }
  }
}

main().catch((err) => {
  console.error(err)
  process.exit(1)
})
