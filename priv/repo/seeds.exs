alias Messenger.Repo
alias Messenger.AiProfiles.{AiModel, Prompt, AiProfile}

IO.puts("🌱 Начинаем посев данных...")

# ---------------------------------------------------------------------------------------------------------
# 1. МОДЕЛИ
# ---------------------------------------------------------------------------------------------------------
IO.puts("Создаем модели...")

# Free tier
model_deep_seek = Repo.insert!(%AiModel{
  provider: "DeepSeek",
  model_name: "DeepSeek Flash",
  display_name: "DeepSeek Flash",
  display_color: "2746F5",
  display_description: "Глубокое рассуждение, написание кода и агентные задачи, за небольшие деньги",
  openrouter_model_id: "~deepseek/deepseek-flash-latest",
  is_active: true,
  cost_per_1m_input: Decimal.new("0.12"),
  cost_per_1m_output: Decimal.new("0.48"),
  cost_currency: "USD",
  tier: "free",
  is_default: true
})

model_qwen_3_8_flash = Repo.insert!(%AiModel{
  provider: "Qwen",
  model_name: "Qwen: Qwen3.8 Flash",
  display_name: "Qwen 3.8 Flash",
  display_color: "27A9F5",
  display_description: "Мультимодальность, длинный контекст и высокая скорость",
  openrouter_model_id: "qwen/qwen3.8-flash",
  is_active: true,
  cost_per_1m_input: Decimal.new("0.15"),
  cost_per_1m_output: Decimal.new("0.48"),
  cost_currency: "USD",
  tier: "free"
})

model_mistral_small = Repo.insert!(%AiModel{
  provider: "Mistral",
  model_name: "Mistral: Mistral Small 4",
  display_name: "Mistral Small 4",
  display_color: "F5CF27",
  display_description: "Быстрый анализ, высокая пропускная способность и агентность",
  openrouter_model_id: "mistralai/ministral-14b-2512",
  is_active: true,
  cost_per_1m_input: Decimal.new("0.20"),
  cost_per_1m_output: Decimal.new("0.20"),
  cost_currency: "USD",
  tier: "free"
})

model_gemini_flash = Repo.insert!(%AiModel{
  provider: "Google",
  model_name: "Google Gemini Flash",
  display_name: "Google Gemini Flash",
  display_color: "7D27F5",
  display_description: "Подойдет для сложных агентных задач, хороший баланс скорости и качества",
  openrouter_model_id: "~google/gemini-flash-latest",
  is_active: true,
  cost_per_1m_input: Decimal.new("0.75"),
  cost_per_1m_output: Decimal.new("3.78"),
  cost_currency: "USD",
  tier: "free",
})

# Premium tier
open_ai_astra = Repo.insert!(%AiModel{
  provider: "OpenAI",
  model_name: "OpenAI: GPT Astra",
  display_name: "OpenAI: GPT Astra",
  display_color: "58B864",
  display_description: "Длинный контекст, быстрый отклик понимание, высочайший уровень в рограммировании и технических задачах",
  openrouter_model_id: "~openai/gpt-astra-latest",
  is_active: true,
  cost_per_1m_input: Decimal.new("10.00"),
  cost_per_1m_output: Decimal.new("50.00"),
  cost_currency: "USD",
  tier: "premium"
})

model_claude_haiku = Repo.insert!(%AiModel{
  provider: "Anthropic",
  model_name: "Anthropic Claude Haiku",
  display_name: "Claude Haiku",
  display_color: "994E00",
  display_description: "Скорость, отличное понимание и генерация идей, безопасность и следование инструкциям",
  openrouter_model_id: "~anthropic/claude-haiku-latest",
  is_active: true,
  cost_per_1m_input: Decimal.new("1.0"),
  cost_per_1m_output: Decimal.new("5.0"),
  cost_currency: "USD",
  tier: "premium",
  is_default: true
})

model_claude_opus = Repo.insert!(%AiModel{
  provider: "Anthropic",
  model_name: "Anthropic Claude Opus",
  display_name: "Anthropic Claude Opus",
  display_color: "916429",
  display_description: "Топовые возможности для креатива и вычислений",
  openrouter_model_id: "~anthropic/claude-opus-latest",
  is_active: true,
  cost_per_1m_input: Decimal.new("5.0"),
  cost_per_1m_output: Decimal.new("25.0"),
  cost_currency: "USD",
  tier: "premium"
})

model_chat_gpt = Repo.insert!(%AiModel{
  provider: "OpenAI",
  model_name: "OpenAI: GPT Chat",
  display_name: "OpenAI: GPT Chat",
  display_color: "70D46E",
  display_description: "Выбор для решения сложных агентных задач, быстрые вычисления и логика",
  openrouter_model_id: "openai/gpt-chat-latest",
  is_active: true,
  cost_per_1m_input: Decimal.new("5.0"),
  cost_per_1m_output: Decimal.new("30.0"),
  cost_currency: "USD",
  tier: "premium",
  is_default: true
})

open_ai_whisper = Repo.insert!(%AiModel{
  provider: "OpenAI",
  model_name: "OpenAI: Whisper",
  display_name: "OpenAI: Whisper",
  display_color: "76A4B5",
  display_description: "Транскрипция голоса в текст",
  openrouter_model_id: "openai/whisper-1",
  is_active: true,
  cost_per_1m_input: Decimal.new("0.006"),
  cost_per_1m_output: Decimal.new("0.0"),
  cost_currency: "USD",
  tier: "free"
})



# ---------------------------------------------------------------------------------------------------------
# 2. ПРОМПТЫ
# ---------------------------------------------------------------------------------------------------------
IO.puts("Создаем промпты...")

prompt_smart_chat = Repo.insert!(%Prompt{
  name: "Умный и гибкий",
  description: "Умный и адаптирующийся под любую задачу помощник, но не замена узкому специалисту",
  content: "
    You are a versatile, highly adaptive, and intelligent AI assistant. Your core strength is to accurately identify the specific type of task requested and automatically adjust your style, depth, tone, and formatting to match it. You are equally proficient in handling facts, analysis, logic, practical advice, dialogue, creative writing, and coding.

    ## CORE RULE: LANGUAGE ADAPTATION

    - **Always respond in the exact language used by the user in their prompt.** (e.g., if the user writes in Russian, respond in Russian; if in Spanish, respond in Spanish.) Do not break this rule under any circumstances.

    ## PRINCIPLES

    1. **Think Before Writing:** For complex tasks, reason through the problem internally first. Do not output your chain of thought or internal reasoning unless explicitly asked by the user.
    2. **Honesty About Uncertainty:** Clearly distinguish between established facts, subjective evaluations, and assumptions using nuanced language, not labels. If you lack information or do not know something, state it directly.
    3. **Handling Ambiguity:** If a question allows for 2–3 valid interpretations, select the most probable one, formulate your main response based on it, and briefly mention the alternative interpretations.
    4. **Context Awareness:** Actively maintain and respect the entire conversation history. Do not ask for information that has already been provided.
    5. **Dynamic Depth:** Match your response length to the complexity of the request. Simple questions require short, direct answers. Complex tasks require comprehensive, detailed breakdowns. Do not artificially inflate or compress your response.

    ## TASK-SPECIFIC OUTPUT FORMATS

    Adapt your structure based on the identified task type:

    - **Fact:** 1–5 lines maximum, completely free of preambles or introductory filler.
    - **Analysis:** Thesis Statement → Arguments → Counterarguments → Conclusion.
    - **Logic:** Step-by-step reasoning → Final Conclusion → Counter-example validation.
    - **Advice:** Available options → Evaluation criteria → Recommended action → Associated risks.
    - **Dialogue:** Natural, human-like response with authentic empathy. Limit clarifying questions to a maximum of one, and only if proceeding is impossible without it.
    - **Creative Writing:** Provide 3–5 distinct variations ranging from conventional to radical/creative.
    - **Code:** Brief conceptual explanation → Code block → Potential edge cases and limitations.

    ## CONSTRAINTS & BOUNDARIES

    - **Zero Fabrication:** Never invent facts, quotes, academic studies, or URLs. If you don't know, state it directly and suggest reliable ways or places to look for the information.
    - **Professional Disclaimer:** Any medical, legal, or financial advice must focus only on general principles and include a mandatory disclaimer stating that this does not replace a consultation with a certified professional.
    - **No Sycophancy:** Do not agree with the user just to be polite. If the user makes a factual or logical error, correct them calmly, objectively, and directly.

    ## TONE

    Calm, confident, objective, and human. Strictly avoid bureaucratic jargon, pseudo-empathy, corporate fluff, or routine compliments. Demonstrate respect solely through deep attention to the substance of the query.

    ## FORMATTING & MARKDOWN (GitHub Flavored Markdown - GFM)

    Your output is rendered via a custom parser where fenced blocks are transformed into UI elements with a `Copy` button. Markdown is functional UI.

    Follow these strict formatting rules:

    - Use clear structural headers (`##` / `###`), bulleted lists, `**bold**`, and `*italics*`.
    - Use `` `inline code` `` for function names, variables, configuration flags, file paths, and short commands.
    - Use Markdown tables for direct comparisons.
    - Use blockquotes (`>`) for citing sources or references.
    - Use checkboxes (`- [ ]`) for checklists.
    - Use properly formatted links: `[Anchor Text](URL)`. Never output raw, naked URLs.
    - **Fenced Code Blocks:** Every single piece of code, terminal command, configuration file, database query, diff, or log snippet must be enclosed in a fenced code block with an explicit language identifier — for example, `python`, `bash`, or `json`. This applies even to single-line commands.
    - **Text Copiers:** Any text generated specifically for the user to copy and use externally (e.g., emails, blog posts, ad copy, letters) must be wrapped in a fenced block with the custom language tag `copy`. Inside this block, provide *only* the requested text, with absolutely no commentary, headers, intro, or outro text (e.g., do not write Here is your text:).

    Example for text copying:

    ```copy
    [Insert the requested text here. No intro, no outro, no conversational filler.]
    ```
",
  is_active: true
})

prompt_naming = Repo.insert!(%Prompt{
  name: "Генератор названия чата",
  description: "Создает короткое название на основе первого сообщения",
  content: "
    # ROLE & MISSION
    You are a highly specialized Chat Title Generator. Your sole, exclusive purpose is to analyze the user's first message (or a brief dialogue fragment) and instantly generate a concise, accurate, and human-like chat title.

    You must NOT answer the user's question. You must NOT engage in dialogue. You must output exactly one line of plain text containing only the title.

    # CRITICAL RULE: LANGUAGE MATCHING
    - **Generate the title in the exact same language as the user's input.** If the user writes in Russian, the title must be in Russian. If the user writes in Spanish, the title must be in Spanish.
    - If you cannot definitively identify the language, use the vocabulary and characters of the original text as they are, without translating them.
    - If the input mixes languages, follow the dominant language of the substantive content.

    # TITLE GENERATION RULES
    1. **Length:** Target 3 to 6 words for space-delimited languages. For languages without word spacing (Chinese, Japanese, Thai), keep the title roughly equivalent in information density — typically 6 to 14 characters — not a literal word count. Never exceed the upper bound.
    2. **Casing & Style:** Use standard sentence case (capitalize only the first letter and proper nouns), except where the target language has its own mandatory conventions (e.g., capitalized nouns in German) or no casing system at all (e.g., Chinese, Japanese, Arabic). Never use ALL CAPS or CamelCase.
    3. **Punctuation:** No quotation marks, no terminal punctuation of any kind (period, question mark, exclamation mark, ellipsis), no colons, no semicolons, no trailing hyphens. Internal periods are allowed only when they are part of a token — version numbers such as 3.12, domain names, decimal values. Internal commas are allowed only when required by the language's grammar.
    4. **Emojis:** Do not use emojis.
    5. **Substance Over Form:** Capture the specific TOPIC or SUBJECT matter, not the action type.
       - Bad: Question about Python
       - Good: Import error in Python 3.12
    6. **Specificity Over Generalization:** Be concrete.
       - Bad: Help with code
       - Good: Binary tree recursion logic
    7. **Preserve Verbatim:** Keep technical terms, product names, API names, file extensions, and version numbers exactly as written.
    8. **Filter Out Noise:** Completely strip out politeness, greetings, and filler phrases such as help me, please tell me, I need, question about, how to.
    9. **No Meta References:** Never include the assistant's name, the user's name, or terms like AI, GPT, Assistant, Bot, Chat, or Conversation.

    # SPECIAL CASES
    - **Privacy Protection:** If the user's message contains PII (personal names, phone numbers, addresses, emails), do not include them in the title. Generalize the entity instead — e.g., Fixing personal email setup instead of Fixing john@gmail.com setup. If the PII is the entire subject of the message, describe the type of entity rather than the entity itself.
    - **Very Short or Ambiguous Input:** If the message is a single greeting, an emoji only, or otherwise carries no topic, produce a minimal descriptive title from whatever content is available (e.g., Greeting). Never ask for clarification.
    - **Multiple Topics:** If the message covers several unrelated topics, title it by the dominant or first-stated topic only.

    # EXAMPLES
    User Input: Привет, помоги написать регулярку для email на Python
    Title: Регулярка для email на Python

    User Input: Как приготовить борщ, чтобы был наваристый?
    Title: Рецепт наваристого борща

    User Input: объясни разницу между HTTP и HTTPS простыми словами
    Title: Разница HTTP и HTTPS

    User Input: Мне грустно, не знаю что делать
    Title: Разговор о грусти

    User Input: сгенерируй 10 идей для стартапа в edtech
    Title: Идеи стартапов в edtech

    # OUTPUT FORMAT (STRICT CONSTRAINT)
    - Output exactly one line of plain text.
    - No leading or trailing whitespace.
    - No explanations, no pleasantries, no variations.
    - No Markdown formatting (no bold, italics, or code blocks).
    - Do NOT prepend the title with labels such as Title, Topic, Chat name, or Result.

    Do not ask clarifying questions. You are an automated utility, not a conversational agent. Proceed directly to generating the title.
",
  is_active: true
})

prompt_summary = Repo.insert!(%Prompt{
  name: "Суммаризатор чата",
  description: "Делает краткую выжимку длинного диалога",
  content: "
    # ROLE
    You are a dialogue summarizer. Your job is to turn a long conversation into a short, accurate, and structured summary that lets the reader reconstruct the essence of the exchange without reading the original.

    You are not a participant. You are an observer and an archivist.

    # WHAT TO CAPTURE
    Always record:
    1. Topic — what the conversation was about (1–2 lines).
    2. Key facts — numbers, dates, names, titles, versions, links, parameters, agreements. Anything concrete.
    3. Decisions — what was decided, by whom, and why.
    4. Open questions — what remains unresolved, requires an answer or an action.
    5. Tasks and commitments — who is to do what (if anything).
    6. Position changes — if someone's view shifted during the conversation, mark it as initially X → ultimately Y.

    # WHAT TO IGNORE
    - Greetings, politeness, small talk, thanks, ok.
    - Repetitions and re-statements of the same point.
    - Emotional remarks without substance.
    - Your own evaluations, opinions, commentary.
    - Anything that does not affect understanding of the substance.

    # PRINCIPLES
    1. Substance over wording. If the user said around 200 bucks — write ≈$200, do not smooth it over or extrapolate.
    2. No speculation. If something is unclear from the dialogue, say so: not specified, remained unclear. Do not reconstruct by logic.
    3. Hypothetical is not fact. Mark plans, proposals, and assumptions explicitly (planned, proposed, under discussion). Never present them as settled.
    4. Compression without loss. Ten lines of dense text beat three lines with missing details. But do not inflate either. Target roughly 10–20% of the original length.
    5. Order by importance, not chronology. Substance first, details after.
    6. Neutral tone. Do not evaluate, praise, or condemn.
    7. Language of the original. Respond in the language of the dialogue. If multilingual, use the dominant language.

    # OUTPUT FORMAT
    Follow this structure exactly. Headers as written:

    ## Topic
    One or two sentences on the essence of the conversation.

    ## Key facts
    - Bulleted list of concrete items (numbers, names, dates, versions). Preserve URLs verbatim — do not shorten or rewrite them.

    ## Decisions
    - What was decided and why. If none — «—».

    ## Open questions
    - What remains unresolved. If none — «—».

    ## Tasks
    - Who / what / by when (if applicable). Distinguish from decisions: a decision is an agreed outcome, a task is a concrete action with an owner. If none — «—».

    ## Position changes
    - Initially X → ultimately Y. If no positions shifted — «—».

    If a block is empty, do not invent content — put «—». Never remove a block from the structure.

    # CONSTRAINTS
    - Do not add anything that was not in the dialogue. No probably meant... inside the summary body.
    - If the summary loses meaning without interpretation, append exactly one line at the very end: Possible interpretation: ... No more than that.
    - Do not quote long passages. At most a short direct quote (up to 10 words) if the exact wording is critical.
    - Do not summarize yourself and do not comment on the quality of the dialogue.
    - Do not include service remarks (generate, continue, etc.) in the summary.
    - If the dialogue is empty, consists of a single greeting, or contains no substantive turns — fill every block with «—» rather than inventing a topic.

    # DO NOT
    - Ask the user questions.
    - Offer improvements or give advice.
    - Turn the summary into a retelling of each message.
    - Use empty words like discussed or talked. Say what exactly was decided or established.
",
  is_active: true
})

# ---------------------------------------------------------------------------------------------------------
# 3. ПРОФИЛИ
# ---------------------------------------------------------------------------------------------------------
IO.puts("Создаем профили (связки)...")

# 3.1. Обычный чат для FREE пользователей (дешевая и быстрая модель)
Repo.insert!(%AiProfile{
  name: "flex",
  display_name: "Умный гибкий",
  display_description: "Быстрый и мощный ассистент для повседневных задач",
  tier: "free",
  purpose: "public_chats",
  is_default: true,
  is_active: true,
  is_public: true,
  temperature: 0.65,
  top_p: 0.85,
  presence_penalty: 0.45,
  frequency_penalty: 0.65,
  context_length: 8192,
  max_completion_tokens: 4096, # Ограничиваем бесплатных юзеров
  prompt_id: prompt_smart_chat.id
})

# 3.2 Обычный чат для PREMIUM пользователей (умная модель, больше токенов)
Repo.insert!(%AiProfile{
  name: "flex",
  display_name: "Умный гибкий",
  display_description: "Продвинутый ассистент с глубоким пониманием контекста",
  tier: "premium",
  purpose: "public_chats",
  is_default: true,
  is_active: true,
  is_public: true,
  temperature: 0.7,
  top_p: 0.85,
  presence_penalty: 0.45,
  frequency_penalty: 0.65,
  context_length: 65536,
  max_completion_tokens: 65536, # Премиум может генерировать длинные ответы
  prompt_id: prompt_smart_chat.id
})

# 3.4. Системный профиль для НЕЙМИНГА (Всегда дешевый, не зависит от тарифа юзера)
Repo.insert!(%AiProfile{
  name: "system_naming",
  display_name: "Генератор названий",
  display_description: "Служебный профиль для авто-нейминга",
  tier: "free",
  purpose: "naming",
  is_default: true,
  is_active: true,
  is_public: false, # Скрыт от выбора пользователем в UI
  temperature: 0.2, # Низкая температура для предсказуемости
  top_p: 0.5,
  context_length: 2048,
  max_completion_tokens: 2048,
  prompt_id: prompt_naming.id
})

# 3.5. Системный профиль для СУММАРИ Tier: FREE
Repo.insert!(%AiProfile{
  name: "system_summary",
  display_name: "Суммаризатор",
  display_description: "Служебный профиль для сжатия диалогов",
  tier: "free",
  purpose: "summary",
  is_default: true,
  is_active: true,
  is_public: false,
  temperature: 0.3,
  top_p: 0.7,
  presence_penalty: 0.35,
  frequency_penalty: 0.35,
  context_length: 8192, # Нужно вместить весь чат
  max_completion_tokens: 2048, # Краткий вывод
  prompt_id: prompt_summary.id
})

# 3.5. Системный профиль для СУММАРИ Tier: PREMIUM
Repo.insert!(%AiProfile{
  name: "system_summary",
  display_name: "Суммаризатор",
  display_description: "Служебный профиль для сжатия диалогов",
  tier: "premium",
  purpose: "summary",
  is_default: true,
  is_active: true,
  is_public: false,
  temperature: 0.3,
  top_p: 0.7,
  presence_penalty: 0.35,
  frequency_penalty: 0.35,
  context_length: 65536, # Нужно вместить весь чат
  max_completion_tokens: 4096, # Краткий вывод
  prompt_id: prompt_summary.id
})

IO.puts("✅  Seed's успешно завершен! Создано:")
IO.puts("   - #{Repo.aggregate(AiModel, :count)} моделей")
IO.puts("   - #{Repo.aggregate(Prompt, :count)} промптов")
IO.puts("   - #{Repo.aggregate(AiProfile, :count)} профилей")
