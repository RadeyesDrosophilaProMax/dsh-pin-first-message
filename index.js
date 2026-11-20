export const name = 'pin-first-message'

/**
 * 把会话里「对方说的第一条用户消息」固定进系统提示。
 *
 * 压缩只会改写历史，系统提示不受影响；因此这段文本一旦挂上，无论压缩多少次
 * 都还在。文本在第一次组装时才读取（会话创建时消息还没到），读到后缓存。
 *
 * @module @local/dsh-pin
 */

export function apply(ctx, config = {}) {
  const raw = config !== null && typeof config === 'object' ? config : {}
  const maxChars = Number.isFinite(raw.maxChars) ? raw.maxChars : 4000
  const header = typeof raw.header === 'string' && raw.header.trim() !== ''
    ? raw.header.trim()
    : '【本会话的开场——对方说的第一句话。始终记得这件事，不要忘记、不要改写：】'

  const extractText = (message) => {
    const parts = Array.isArray(message?.content) ? message.content : []
    const text = parts
      .map((part) => {
        if (typeof part === 'string') return part
        if (part === null || typeof part !== 'object') return ''
        if (typeof part.text === 'string') return part.text
        if (typeof part.content === 'string') return part.content
        return ''
      })
      .filter((line) => line.trim() !== '')
      .join('\n')
      .trim()
    return text
  }

  const findFirstUserMessage = (session) => {
    const nodes = session?.surface?.nodes
    if (!Array.isArray(nodes) || typeof session.eventAt !== 'function') return ''
    for (const seq of nodes) {
      let event
      try {
        event = session.eventAt(seq)
      } catch {
        continue
      }
      if (event?.type !== 'user/message') continue
      const text = extractText(event.data)
      if (text !== '') return text.length > maxChars ? `${text.slice(0, maxChars)}…` : text
    }
    return ''
  }

  ctx.on('agent/created', (payload) => {
    const agent = payload?.agent
    const session = agent?.session
    if (session === undefined || session === null) return undefined

    const agentCtx = agent?.ctx
    const service = typeof agentCtx?.get === 'function' ? agentCtx.get('systemPrompt') : agentCtx?.systemPrompt
    if (service === undefined || service === null || typeof service.section !== 'function') return undefined

    const base = typeof service.getSectionOrder === 'function' ? service.getSectionOrder('DEPLOYMENT_PERSONA_PREFIX') : 0
    const sessionId = String(session.id ?? '')
    let cached = ''

    const text = () => {
      if (cached !== '') return cached
      const first = findFirstUserMessage(session)
      if (first === '') return ''
      cached = `${header}\n${first}`
      return cached
    }

    try {
      const disposer = service.section({
        name: `pin-first-message:${sessionId.slice(-8)}`,
        order: (Number.isFinite(base) ? base : 0) + 1,
        text,
      })
      if (typeof agentCtx.effect === 'function') agentCtx.effect(() => disposer, 'pin first message')
    } catch (error) {
      console.log(`[pin-first-message] failed: ${error instanceof Error ? error.message : String(error)}`)
    }
    return undefined
  })
}
