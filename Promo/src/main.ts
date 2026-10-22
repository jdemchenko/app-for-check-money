import './style.css'

type Slide = {
  id: string
  layout?: 'split' | 'solo'
  eyebrow?: string
  brand?: boolean
  title: string
  body: string
  en: string
  meta?: string
  visual: string
}

const slides: Slide[] = [
  {
    id: 'hero',
    layout: 'solo',
    brand: true,
    title: 'Деньги — на скорости речи',
    body: 'Voice-first личный трекер финансов для iPhone. Тихий Liquid Glass, BYN по умолчанию, всё на устройстве.',
    en: 'Voice-first personal finance · quiet Liquid Glass · BYN-first',
    meta: '<strong>Ivan Demchenko</strong> · CheckMoney / AppForCheckMoney',
    visual: `
      <div class="orb orb-a"></div>
      <div class="orb orb-b"></div>
      <div class="glass-card">
        <p class="label">Сегодня</p>
        <p class="value">−48,20 Br</p>
        <p class="hint">Удерживай и говори — сумма уже в журнале</p>
      </div>
    `,
  },
  {
    id: 'voice',
    layout: 'split',
    eyebrow: 'Голос',
    title: 'Сказал — учтено',
    body: 'Удерживай кнопку на Home и говори. On-device NLP понимает сумму, тип, валюту и категорию — без облачного AI.',
    en: 'Hold to talk · on-device NLP · QuietConfirm',
    visual: `
      <div class="wave" aria-hidden="true">
        <span></span><span></span><span></span><span></span><span></span><span></span><span></span>
      </div>
      <div class="glass-card">
        <p class="label">Распознано</p>
        <p class="value">«кофе 8»</p>
        <p class="hint">Кафе · 8,00 Br · расход</p>
      </div>
    `,
  },
  {
    id: 'multi',
    layout: 'split',
    eyebrow: 'Мульти · Recurring',
    title: 'Одна фраза — несколько строк',
    body: '«Кофе 5 и такси 12» → пачка с подтверждением. «Нетфликс 20 каждый месяц» → recurring-правило. Всё локально.',
    en: 'Multi-tx voice · recurring from speech',
    visual: `
      <div class="stack-lines">
        <div class="row"><span>Кофе</span><span class="amt">5,00 Br</span></div>
        <div class="row"><span>Такси</span><span class="amt">12,00 Br</span></div>
        <div class="row"><span>Netflix · каждый месяц</span><span class="amt">20,00 Br</span></div>
      </div>
    `,
  },
  {
    id: 'privacy',
    layout: 'split',
    eyebrow: 'Приватность',
    title: 'Данные никуда не уходят',
    body: 'Парсинг на устройстве, без нашего бэкенда и без аккаунта. Face ID / Touch ID закрывает вход — тихо и по делу.',
    en: 'On-device NLP · no cloud AI · Face ID lock',
    visual: `
      <div class="lock-ring" aria-hidden="true"></div>
      <div class="glass-card">
        <p class="label">Защита</p>
        <p class="value">Face ID</p>
        <p class="hint">Журнал остаётся только у вас</p>
      </div>
    `,
  },
  {
    id: 'byn',
    layout: 'split',
    eyebrow: 'Валюта',
    title: 'BYN — родной язык денег',
    body: 'Белорусский рубль по умолчанию для ввода и отображения. «Руб» → BYN. Мультивалюта на операции с понятным pivot.',
    en: 'BYN-first · multi-currency · Br symbol',
    visual: `
      <div class="currency-chip">Br</div>
      <div class="currency-chip alt">USD · EUR · RUB</div>
      <div class="glass-card">
        <p class="label">Баланс</p>
        <p class="value">1 240,50 Br</p>
        <p class="hint">Display &amp; entry default · BYN</p>
      </div>
    `,
  },
  {
    id: 'stats',
    layout: 'split',
    eyebrow: 'Статистика',
    title: 'Тихая аналитика',
    body: 'Сравнение с прошлым периодом, дневной средний, средний чек, крупнейшие суммы — без шума дашборда.',
    en: 'Quiet insights · vs last · daily avg',
    visual: `
      <div class="bars" aria-hidden="true">
        <i></i><i></i><i></i><i></i><i></i><i></i><i></i>
      </div>
      <div class="glass-card">
        <p class="label">Этот месяц</p>
        <p class="value">−12% к прошлому</p>
        <p class="hint">Средний чек · топ категорий</p>
      </div>
    `,
  },
  {
    id: 'budgets',
    layout: 'split',
    eyebrow: 'Бюджеты',
    title: 'Лимиты без тревоги',
    body: 'Месячный spend limit и тихие полосы по категориям на Home. Контроль виден, но не кричит.',
    en: 'Monthly limit · category budgets · quiet bars',
    visual: `
      <div class="budget">
        <div>
          <div class="cap"><span>Еда</span><span>62%</span></div>
          <div class="track"><div class="fill a"></div></div>
        </div>
        <div>
          <div class="cap"><span>Транспорт</span><span>38%</span></div>
          <div class="track"><div class="fill b"></div></div>
        </div>
        <div>
          <div class="cap"><span>Месяц</span><span>81%</span></div>
          <div class="track"><div class="fill c"></div></div>
        </div>
      </div>
    `,
  },
  {
    id: 'widgets',
    layout: 'split',
    eyebrow: 'Виджеты',
    title: 'Взгляд с Home Screen',
    body: 'Small, Medium и Large: баланс, бюджет и 7-дневные бары — без открытия приложения.',
    en: 'Widgets S / M / L · 7-day bars',
    visual: `
      <div class="widget-grid">
        <div class="widget">
          <span class="w-label">Сегодня</span>
          <p class="w-value">−18 Br</p>
        </div>
        <div class="widget">
          <span class="w-label">Бюджет</span>
          <p class="w-value">81%</p>
        </div>
        <div class="widget wide">
          <span class="w-label">7 дней</span>
          <p class="w-value">Тихие бары на Large</p>
        </div>
      </div>
    `,
  },
  {
    id: 'siri',
    layout: 'split',
    eyebrow: 'Siri · Shortcuts',
    title: 'Добавь расход голосом Siri',
    body: 'App Intents: «добавить расход» и лог из текста — Action Button, Back Tap, Shortcuts. Без облака.',
    en: 'App Intents · Siri · Shortcuts',
    visual: `
      <div class="siri-pill">«CheckMoney, кофе 8»</div>
      <div class="glass-card">
        <p class="label">Intent</p>
        <p class="value">AddExpense</p>
        <p class="hint">Без открытия UI · on-device</p>
      </div>
    `,
  },
  {
    id: 'cta',
    layout: 'solo',
    brand: true,
    title: 'Скоро в TestFlight и App Store',
    body: 'Личный voice-first трекер без подписки и без облачного AI. Тихий premium для iPhone.',
    en: 'TestFlight / App Store — coming soon',
    meta: '<strong>Ivan Demchenko</strong> · CheckMoney',
    visual: `
      <div class="orb orb-a"></div>
      <div class="orb orb-b"></div>
      <div class="glass-card">
        <p class="label">Статус</p>
        <p class="value">Launch candidate 1.1</p>
        <p class="hint">Build 24 · Personal Team</p>
      </div>
    `,
  },
]

function renderSlide(slide: Slide, index: number): string {
  const titleBlock = slide.brand
    ? `<h1 class="brand">Check<span>Money</span></h1>
       <p class="headline" style="max-width:18ch">${slide.title}</p>`
    : `<p class="eyebrow">${slide.eyebrow ?? ''}</p>
       <h2 class="headline">${slide.title}</h2>`

  const copy = `
    <div class="copy">
      ${titleBlock}
      <p class="lede">${slide.body}</p>
      <p class="en">${slide.en}</p>
      ${slide.meta ? `<div class="meta">${slide.meta}</div>` : ''}
      ${
        slide.id === 'cta'
          ? `<div class="cta-panel">
               <p>Пишите для TestFlight-доступа. App Store — в подготовке.</p>
               <p class="soon">Coming soon</p>
             </div>`
          : ''
      }
    </div>
  `

  const visual = `<div class="visual" aria-hidden="true">${slide.visual}</div>`

  return `
    <section class="slide${index === 0 ? ' is-active' : ''}" data-layout="${slide.layout ?? 'solo'}" data-id="${slide.id}" aria-hidden="${index === 0 ? 'false' : 'true'}">
      <div class="slide-inner">
        ${copy}
        ${visual}
      </div>
    </section>
  `
}

const params = new URLSearchParams(location.search)
if (params.get('clean') === '1') {
  document.body.classList.add('clean')
}

const startIndex = Math.min(
  Math.max(0, Number(params.get('slide') ?? '1') - 1),
  slides.length - 1,
)

const app = document.querySelector<HTMLDivElement>('#app')!

app.innerHTML = `
  <div class="deck" tabindex="0" role="application" aria-label="CheckMoney promo deck">
    <div class="atmosphere" aria-hidden="true"></div>
    <div class="progress" aria-hidden="true"><i></i></div>
    <div class="slides">
      ${slides.map(renderSlide).join('')}
    </div>
    <div class="chrome">
      <div class="slide-count" aria-live="polite"></div>
      <div class="dots" role="tablist" aria-label="Слайды"></div>
      <div class="hint-keys">← → · Space · Home/End</div>
      <div class="nav">
        <button type="button" data-nav="prev" aria-label="Предыдущий">‹</button>
        <button type="button" data-nav="next" aria-label="Следующий">›</button>
      </div>
    </div>
  </div>
`

const deck = app.querySelector<HTMLDivElement>('.deck')!
const slideEls = [...app.querySelectorAll<HTMLElement>('.slide')]
const dots = app.querySelector<HTMLDivElement>('.dots')!
const countEl = app.querySelector<HTMLDivElement>('.slide-count')!
const progressBar = app.querySelector<HTMLElement>('.progress > i')!

dots.innerHTML = slides
  .map(
    (_, i) =>
      `<button type="button" role="tab" aria-label="Слайд ${i + 1}" data-goto="${i}"></button>`,
  )
  .join('')

let index = startIndex

function go(next: number) {
  index = (next + slides.length) % slides.length
  slideEls.forEach((el, i) => {
    const active = i === index
    el.classList.toggle('is-active', active)
    el.setAttribute('aria-hidden', active ? 'false' : 'true')
  })
  dots.querySelectorAll('button').forEach((btn, i) => {
    btn.classList.toggle('is-active', i === index)
  })
  countEl.textContent = `${String(index + 1).padStart(2, '0')} / ${String(slides.length).padStart(2, '0')}`
  progressBar.style.width = `${((index + 1) / slides.length) * 100}%`
  const url = new URL(location.href)
  url.searchParams.set('slide', String(index + 1))
  history.replaceState(null, '', url)
}

deck.addEventListener('keydown', (e) => {
  if (e.key === 'ArrowRight' || e.key === ' ' || e.key === 'PageDown') {
    e.preventDefault()
    go(index + 1)
  } else if (e.key === 'ArrowLeft' || e.key === 'PageUp') {
    e.preventDefault()
    go(index - 1)
  } else if (e.key === 'Home') {
    e.preventDefault()
    go(0)
  } else if (e.key === 'End') {
    e.preventDefault()
    go(slides.length - 1)
  }
})

app.querySelector('[data-nav="prev"]')?.addEventListener('click', () => go(index - 1))
app.querySelector('[data-nav="next"]')?.addEventListener('click', () => go(index + 1))
dots.addEventListener('click', (e) => {
  const target = (e.target as HTMLElement).closest<HTMLButtonElement>('button[data-goto]')
  if (!target) return
  go(Number(target.dataset.goto))
})

let touchX = 0
deck.addEventListener(
  'touchstart',
  (e) => {
    touchX = e.changedTouches[0]?.clientX ?? 0
  },
  { passive: true },
)
deck.addEventListener(
  'touchend',
  (e) => {
    const x = e.changedTouches[0]?.clientX ?? 0
    const dx = x - touchX
    if (Math.abs(dx) < 48) return
    go(dx < 0 ? index + 1 : index - 1)
  },
  { passive: true },
)

go(index)
deck.focus()
