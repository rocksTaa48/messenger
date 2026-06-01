defmodule Messenger.Vault do
  use Cloak.Vault, otp_app: :messenger

  @impl Cloak.Vault
  def init(config) do
    # Напрямую берем то, что runtime.exs записал в конфигурацию этого модуля
    runtime_config = Application.get_env(:messenger, __MODULE__, [])

    # Объединяем дефолтные настройки компиляции и динамические настройки рантайма
    {:ok, Keyword.merge(config, runtime_config)}
  end
end
