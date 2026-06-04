defmodule Messenger.AiProfiles.AiList do
  @providers_and_models %{
    "openai" => ~w(gpt-4o gpt-4o-mini o1 o3-mini),
    "deepseek" => ~w(deepseek-v4-pro deepseek-v4-flash),
    "anthropic" => ~w(claude-3-7-sonnet-latest claude-3-5-haiku-latest claude-3-opus-latest),
    "gemini" => ~w(gemini-3.5-pro gemini-2.5-flash gemini-2.5-flash-lite),
    "mistral" => ~w(mistral-large-latest mistral-medium-3.5 mistral-small-4),
    "qween" => ~w(qwen3.6-plus qwen3-coder-plus qwen3-max)
  }

  def providers, do: Map.keys(@providers_and_models)

  def valid_model?(provider, model) do
    models = Map.get(@providers_and_models, provider, [])
    model in models
  end
end
