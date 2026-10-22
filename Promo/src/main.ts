import './style.css'

const checkSvg = `
<svg viewBox="0 0 64 64" fill="none" aria-hidden="true">
  <path d="M14 34.5 26.5 47 50 18" stroke="#F5F5F7" stroke-width="7" stroke-linecap="round" stroke-linejoin="round"/>
</svg>`

const micSvg = `
<svg viewBox="0 0 64 64" aria-hidden="true">
  <rect x="24" y="10" width="16" height="28" rx="8"/>
  <path d="M18 30a14 14 0 0 0 28 0"/>
  <path d="M32 44v10"/>
  <path d="M22 54h20"/>
</svg>`

const lockSvg = `
<svg viewBox="0 0 64 64" aria-hidden="true">
  <rect x="14" y="28" width="36" height="28" rx="8"/>
  <path d="M22 28v-6a10 10 0 0 1 20 0v6"/>
</svg>`

type Frame = {
  id: string
  file: string
  html: string
}

const frames: Frame[] = [
  {
    id: 'hero',
    file: '01-hero.png',
    html: `
      <div class="safe hero-stack">
        <div class="brand-row">
          <div class="brand-mark">${checkSvg}</div>
          <div class="brand-name">CheckMoney</div>
        </div>
        <p class="line">Деньги — голосом</p>
        <div class="big-visual">
          <div class="phone">
            <div class="phone-screen">
              <div class="status"><span>9:41</span><span>●●●</span></div>
              <h1 class="nav-title">CheckMoney</h1>
              <div class="glass balance-card">
                <p class="balance-label">Баланс</p>
                <p class="balance-value">1 284 Br</p>
                <div class="balance-meta">
                  <span class="in">↓ 2 400</span>
                  <span class="out">↑ 1 116</span>
                </div>
                <div class="budget">
                  <div class="budget-row"><span>Бюджет</span><span>420 / 1 000</span></div>
                  <div class="track"><i></i></div>
                </div>
              </div>
              <div class="mic-wrap">
                <div class="mic">${micSvg}</div>
              </div>
              <p class="mic-caption">Удерживайте</p>
              <div class="glass recent">
                <div class="tx">
                  <div class="glyph">☕</div>
                  <div class="tx-main"><strong>Еда</strong><span>кофе</span></div>
                  <div class="tx-amt">−8 Br</div>
                </div>
                <div class="tx">
                  <div class="glyph">🚗</div>
                  <div class="tx-main"><strong>Транспорт</strong><span>такси</span></div>
                  <div class="tx-amt">−12 Br</div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    `,
  },
  {
    id: 'voice',
    file: '02-voice.png',
    html: `
      <div class="safe hero-stack">
        <div class="brand-row">
          <div class="brand-mark">${checkSvg}</div>
          <div class="brand-name">CheckMoney</div>
        </div>
        <p class="line">Сказал — учтено</p>
        <div class="big-visual" style="flex-direction:column;gap:28px">
          <div class="wave" aria-hidden="true">
            <span></span><span></span><span></span><span></span><span></span><span></span><span></span>
          </div>
          <div class="mic" style="width:200px;height:200px">${micSvg}</div>
          <div class="glass bubble">«кофе 8»</div>
        </div>
      </div>
    `,
  },
  {
    id: 'flow',
    file: '03-voice-flow.png',
    html: `
      <div class="safe hero-stack">
        <div class="brand-row">
          <div class="brand-mark">${checkSvg}</div>
          <div class="brand-name">CheckMoney</div>
        </div>
        <p class="line">Голос → запись</p>
        <div class="big-visual">
          <div class="flow">
            <div class="glass flow-card">
              <p class="k">Фраза</p>
              <p class="v">кофе 5<br>и такси 12</p>
            </div>
            <div class="flow-arrow">→</div>
            <div class="glass flow-card">
              <p class="k">Журнал</p>
              <p class="v" style="font-size:32px;line-height:1.35">Еда −5<br>Такси −12</p>
            </div>
          </div>
        </div>
      </div>
    `,
  },
  {
    id: 'stats',
    file: '04-stats.png',
    html: `
      <div class="safe hero-stack">
        <div class="brand-row">
          <div class="brand-mark">${checkSvg}</div>
          <div class="brand-name">CheckMoney</div>
        </div>
        <p class="line">Неделя в барах</p>
        <div class="big-visual">
          <div class="glass bars" aria-hidden="true">
            <div class="col"><div class="bar" style="height:38%"></div><span class="d">пн</span></div>
            <div class="col"><div class="bar" style="height:62%"></div><span class="d">вт</span></div>
            <div class="col"><div class="bar" style="height:28%"></div><span class="d">ср</span></div>
            <div class="col"><div class="bar" style="height:84%"></div><span class="d">чт</span></div>
            <div class="col"><div class="bar" style="height:48%"></div><span class="d">пт</span></div>
            <div class="col"><div class="bar" style="height:70%"></div><span class="d">сб</span></div>
            <div class="col"><div class="bar" style="height:44%"></div><span class="d">вс</span></div>
          </div>
        </div>
      </div>
    `,
  },
  {
    id: 'categories',
    file: '05-categories.png',
    html: `
      <div class="safe hero-stack">
        <div class="brand-row">
          <div class="brand-mark">${checkSvg}</div>
          <div class="brand-name">CheckMoney</div>
        </div>
        <p class="line">Куда уходит</p>
        <div class="big-visual">
          <div class="rings" aria-hidden="true">
            <div class="ring a"></div>
            <div class="ring b"></div>
            <div class="ring c"></div>
            <div class="ring-center">
              <p class="k">месяц</p>
              <p class="v">1 116</p>
            </div>
          </div>
        </div>
      </div>
    `,
  },
  {
    id: 'widget',
    file: '06-widget.png',
    html: `
      <div class="safe hero-stack">
        <div class="brand-row">
          <div class="brand-mark">${checkSvg}</div>
          <div class="brand-name">CheckMoney</div>
        </div>
        <p class="line">На домашнем экране</p>
        <div class="big-visual">
          <div class="glass widget">
            <p class="k">CheckMoney</p>
            <p class="v">1 284 Br</p>
            <p class="sub">сегодня −48 Br</p>
            <div class="widget-bars" aria-hidden="true">
              <i style="height:35%"></i>
              <i style="height:58%"></i>
              <i style="height:28%"></i>
              <i style="height:76%"></i>
              <i style="height:44%"></i>
              <i style="height:62%"></i>
              <i style="height:50%"></i>
            </div>
          </div>
        </div>
      </div>
    `,
  },
  {
    id: 'lock',
    file: '07-lock.png',
    html: `
      <div class="safe hero-stack">
        <div class="brand-row">
          <div class="brand-mark">${checkSvg}</div>
          <div class="brand-name">CheckMoney</div>
        </div>
        <p class="line">Только вы</p>
        <div class="big-visual">
          <div class="glass lock">
            <div class="icon">${lockSvg}</div>
            <p class="v">Face ID</p>
          </div>
        </div>
      </div>
    `,
  },
  {
    id: 'cta',
    file: '08-cta.png',
    html: `
      <div class="safe">
        <div class="cta-center">
          <div class="cta-mark">${checkSvg}</div>
          <p class="cta-name">CheckMoney</p>
          <p class="cta-line">на скорости речи</p>
        </div>
      </div>
    `,
  },
]

function brandMarkFix() {
  // Replace emoji glyphs in hero recent with sparse SF-like symbols via CSS letters.
}

function render() {
  const params = new URLSearchParams(location.search)
  const exportMode = params.has('export') || params.has('clean')
  if (exportMode) document.body.classList.add('export-mode')

  // Prefer non-emoji glyphs in the phone mock (Threads-safe, quiet).
  const homeHtml = frames[0].html
    .replaceAll('☕', '◉')
    .replaceAll('🚗', '▸')
  frames[0].html = homeHtml
  brandMarkFix()

  const only = params.get('frame')
  const list = only ? frames.filter((f) => f.id === only || f.file.startsWith(only)) : frames

  const app = document.querySelector<HTMLDivElement>('#app')
  if (!app) return

  app.innerHTML = `
    <div class="deck">
      ${
        exportMode
          ? ''
          : `<div class="hud"><strong>Threads</strong> · 1080×1920 · ←→ · <code>?export=1</code></div>`
      }
      ${list
        .map(
          (f) => `
        <section class="frame" data-frame="${f.id}" data-file="${f.file}" aria-label="${f.id}">
          ${f.html}
        </section>`
        )
        .join('')}
    </div>
  `

  if (!exportMode) {
    let index = 0
    const sections = [...document.querySelectorAll<HTMLElement>('.frame')]
    const focus = () => sections[index]?.scrollIntoView({ behavior: 'smooth', block: 'center' })
    window.addEventListener('keydown', (e) => {
      if (e.key === 'ArrowRight' || e.key === ' ' || e.key === 'PageDown') {
        e.preventDefault()
        index = Math.min(sections.length - 1, index + 1)
        focus()
      } else if (e.key === 'ArrowLeft' || e.key === 'PageUp') {
        e.preventDefault()
        index = Math.max(0, index - 1)
        focus()
      }
    })
  }

  ;(window as unknown as { __CHECKMONEY_FRAMES__: Frame[] }).__CHECKMONEY_FRAMES__ = frames
}

render()
