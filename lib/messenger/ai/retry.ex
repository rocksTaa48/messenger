defmodule Messenger.Ai.Retry do
  require Logger

  @max_attempts 3

  @doc"""
  Передаем сюда функцию которую нужно ретраить, в случае :retry выполняется повторный вызов max_attempts-раз
  """
  def call(fun) do
    run_with_retry(fun, 1)
  end

  defp run_with_retry(fun, attempt) do
    case fun.() do
      {:retry, reason} when attempt < @max_attempts ->
        delay = attempt * 1000
        Logger.warning("😮 Retry #{attempt}/#{@max_attempts} через #{delay}мс: #{reason}")
        Process.sleep(delay)
        run_with_retry(fun, attempt + 1)

      {:retry, reason} ->
        Logger.error("🤬 Превышен лимит попыток (#{@max_attempts}): #{reason}")
        {:error, {:max_retries_exceeded, reason}}

      other ->
        other
    end
  end
end