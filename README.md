# dsh-pin-first-message

给 [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness) 用的一个小插件：**把会话里对方说的第一句话钉进系统提示**，让它永远不被上下文压缩吃掉。

> 长对话里，前面的内容会被摘要压缩掉。开场那句——身份、场景、设定、约定——往往是最重要的，却最早消失。这个插件把它搬到系统提示里，压缩碰不到系统提示。

## 效果

```
会话开始
  └─ 插件读出第一条 user 消息
       └─ 挂进 system prompt（永久段）
            └─ 之后每次压缩，这段都不动
```

实际注入的样子：

```
【本会话的开场——对方说的第一句话。始终记得这件事，不要忘记、不要改写：】
（傍晚，我把门推开一半）进来吧。你叫什么名字？
```

## 安装

### 一句命令（Windows PowerShell）

```powershell
irm https://raw.githubusercontent.com/RadeyesDrosophilaProMax/dsh-pin-first-message/main/install.ps1 | iex
```

它会自动：克隆仓库 → 建目录联接 → 写 `package.json` 依赖 → 追加 `cordis.patch.yml` 条目。
profile 目录会自动查找，找不到时用 `-Profile` 指定：

```powershell
.\install.ps1 -Profile "D:\DSshuju\profiles\desktop"
```

完成后重启 DSH，**新建**会话就生效。

### 手动安装

#### 1. 克隆

```powershell
git clone https://github.com/RadeyesDrosophilaProMax/dsh-pin-first-message.git D:\DSHAI\dsh-pin
```

#### 2. 注册到 profile

编辑 `<profile>\package.json`，在 `dependencies` 里加一行（路径改成你的）：

```json
"@local/dsh-pin": "link:D:/DSHAI/dsh-pin"
```

然后在 profile 的 `node_modules/@local/` 下建一个目录联接（Windows）：

```powershell
New-Item -ItemType Junction `
  -Path  "<profile>\node_modules\@local\dsh-pin" `
  -Target "D:\DSHAI\dsh-pin"
```

#### 3. 加补丁条目

在 profile 的 `cordis.patch.yml` 末尾追加：

```yaml
# 固定记忆：把会话里对方说的第一句话挂进系统提示，压缩拿不走。
- insert:
    - id: pin-first-message
      name: '@local/dsh-pin'
```

重启 DSH，之后**新建**的会话就生效了。

## 配置

```yaml
- insert:
    - id: pin-first-message
      name: '@local/dsh-pin'
      config:
        maxChars: 4000     # 单条钉住的最长字符数，超出截断
        header: '【本会话的开场】'   # 注入在正文前的标题行
```

| 字段 | 默认 | 说明 |
|---|---|---|
| `maxChars` | `4000` | 钉住内容的上限；太长会挤占上下文 |
| `header` | 内置中文标题 | 注入时放在正文前的一行 |

## 已知限制

- **只对新会话生效**：插件在 `agent/created` 时注册，重启前已存在的会话没有
- **对全部会话生效**：包括子代理和普通编码会话；如需收窄范围，可自行按 `session.id` 或模型过滤
- **文本在第一次读取后缓存**：钉住的是当时的原文，之后不会跟着改
- 若第一条消息是空的（例如只有附件），不会注入

## 原理

DSH 的压缩只改写对话历史（surface），系统提示是独立的一段，永远在最前面。插件通过 `systemPrompt.section()` 注册一段文本，内容来自会话日志里第一条 `user/message`：

```js
ctx.on('agent/created', ({ agent }) => {
  const session = agent.session
  const service = agent.ctx.get('systemPrompt')
  service.section({
    name: `pin-first-message:${session.id.slice(-8)}`,
    order: 1,
    text: () => findFirstUserMessage(session),
  })
})
```

## 许可

MIT
