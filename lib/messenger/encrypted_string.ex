defmodule Messenger.EncryptedString do
  use Cloak.Ecto.Type,
      vault: Messenger.Vault,
      type: :string

  # Переопределяем базовые методы, чтобы гарантировать правильное приведение типов в Ecto
  @impl Ecto.Type
  def cast(value) when is_binary(value), do: {:ok, value}
  def cast(_), do: :error
end
