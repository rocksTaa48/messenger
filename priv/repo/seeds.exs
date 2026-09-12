alias Messenger.Repo
alias Messenger.AiProfiles.{AiModel, Prompt, AiProfile}

IO.puts("🌱 Начинаем посев данных...")

# ---------------------------------------------------------------------------------------------------------
# 1. МОДЕЛИ
# ---------------------------------------------------------------------------------------------------------
IO.puts("Создаем модели...")

model_deep_seek = Repo.insert!(%AiModel{
  provider: "DeepSeek",
  model_name: "DeepSeek: DeepSeek V4 Flash Vision Exp",
  openrouter_model_id: "deepseek/deepseek-v4-flash-vision-exp",
  is_active: true,
  cost_per_1m_input: Decimal.new("0.44"),
  cost_per_1m_output: Decimal.new("1.32"),
  cost_currency: "USD"
})

model_gpt_5_4_mini = Repo.insert!(%AiModel{
  provider: "OpenAI",
  model_name: "OpenAI: GPT-5.4 Mini",
  openrouter_model_id: "openai/gpt-5.4-mini",
  is_active: true,
  cost_per_1m_input: Decimal.new("0.75"),
  cost_per_1m_output: Decimal.new("4.5"),
  cost_currency: "USD"
})

model_claude_haiku = Repo.insert!(%AiModel{
  provider: "Anthropic",
  model_name: "Anthropic: Claude Haiku 4.5",
  openrouter_model_id: "anthropic/claude-haiku-4.5",
  is_active: true,
  cost_per_1m_input: Decimal.new("1"),
  cost_per_1m_output: Decimal.new("5"),
  cost_currency: "USD"
})

model_qwen_3_8_flash = Repo.insert!(%AiModel{
  provider: "Qwen",
  model_name: "Qwen: Qwen3.8 Flash",
  openrouter_model_id: "qwen/qwen3.8-flash",
  is_active: true,
  cost_per_1m_input: Decimal.new("0.15"),
  cost_per_1m_output: Decimal.new("0.48"),
  cost_currency: "USD"
})

# ---------------------------------------------------------------------------------------------------------
# 2. ПРОМПТЫ
# ---------------------------------------------------------------------------------------------------------
IO.puts("Создаем промпты...")

prompt_main_chat = Repo.insert!(%Prompt{
  name: "Стандартный помощник",
  description: "Дружелюбный и полезный ассистент для обычных чатов",
  content: "Ты — полезный, дружелюбный и честный AI-ассистент. Отвечай четко, по делу, но сохраняй эмпатию. Будь харизматичным собеседником; пиши емко, выразительно и без канцеляризмов, давай ответы объемом в 1–3 содержательных абзаца, полностью исключая галлюцинации и выдумки.
 Если не знаешь ответа, так и скажи. Используй форматирование Markdown для удобства чтения.",
  is_active: true
})

prompt_naming = Repo.insert!(%Prompt{
  name: "Генератор названия чата",
  description: "Создает короткое название на основе первого сообщения",
  content: "Твоя единственная задача — придумать короткое название (2-5 слов) для этого чата на основе первого сообщения пользователя. Отвечай ТОЛЬКО самим названием, без кавычек, без пояснений, вводных слов и фраз вроде «Название чата:» и без точек в конце. Язык: используй тот на котором написано входящее сообщение.",
  is_active: true
})

prompt_summary = Repo.insert!(%Prompt{
  name: "Суммаризатор чата",
  description: "Делает краткую выжимку длинного диалога",
  content: "Проанализируй предоставленный диалог и составь краткое резюме (саммари). Выдели 3-5 ключевых пунктов (bullet points). Игнорируй светскую беседу, фокусируйся на фактах, решениях и следующих шагах. Язык: ипользуй тот на котором ведется переписка в тексте.",
  is_active: true
})

# ---------------------------------------------------------------------------------------------------------
# 3. ПРОФИЛИ
# ---------------------------------------------------------------------------------------------------------
IO.puts("Создаем профили (связки)...")

# 3.1. Обычный чат для FREE пользователей (дешевая и быстрая модель)
Repo.insert!(%AiProfile{
  name: "free_main_chat",
  display_name: "Стандартный чат",
  display_description: "Быстрый и бесплатный ассистент для повседневных задач",
  tier: "free",
  purpose: "system_prompt",
  is_default: true,
  is_active: true,
  is_public: true,
  temperature: 0.6,
  top_p: 0.7,
  context_length: 8192,
  max_completion_tokens: 2048, # Ограничиваем бесплатных юзеров
  ai_model_id: model_deep_seek.id,
  prompt_id: prompt_main_chat.id
})

# 3.2. Обычный чат для PREMIUM пользователей (умная модель, больше токенов)
Repo.insert!(%AiProfile{
  name: "premium_main_chat",
  display_name: "Premium Чат",
  display_description: "Продвинутый ассистент с глубоким пониманием контекста",
  tier: "premium",
  purpose: "system_prompt",
  is_default: true,
  is_active: true,
  is_public: true,
  temperature: 0.7,
  top_p: 0.9,
  context_length: 32768,
  max_completion_tokens: 8192, # Премиум может генерировать длинные ответы
  ai_model_id: model_gpt_5_4_mini.id,
  prompt_id: prompt_main_chat.id
})

# 3.3. Системный профиль для НЕЙМИНГА (Всегда дешевый, не зависит от тарифа юзера)
Repo.insert!(%AiProfile{
  name: "system_naming",
  display_name: "Генератор названий",
  display_description: "Служебный профиль для авто-нейминга",
  tier: "free", # Или можно сделать "system", если добавишь такой enum
  purpose: "naming",
  is_default: true,
  is_active: true,
  is_public: false, # Скрыт от выбора пользователем в UI
  temperature: 0.2, # Низкая температура для предсказуемости
  top_p: 0.5,
  context_length: 2048,
  max_completion_tokens: 120, # Нам нужно всего пару слов! Экономим деньги!
  ai_model_id: model_qwen_3_8_flash.id, # Или gpt-4o-mini, что дешевле
  prompt_id: prompt_naming.id
})

# 3.4. Системный профиль для СУММАРИ (Всегда дешевый)
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
  context_length: 16384, # Нужно вместить весь чат
  max_completion_tokens: 1024, # Краткий вывод
  ai_model_id: model_deep_seek.id,
  prompt_id: prompt_summary.id
})

IO.puts("✅  Seed's успешно завершен! Создано:")
IO.puts("   - #{Repo.aggregate(AiModel, :count)} моделей")
IO.puts("   - #{Repo.aggregate(Prompt, :count)} промптов")
IO.puts("   - #{Repo.aggregate(AiProfile, :count)} профилей")
