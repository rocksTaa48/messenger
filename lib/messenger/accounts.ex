defmodule Messenger.Accounts do

  import Ecto.Query, warn: false
  alias Messenger.Repo
  alias Messenger.Accounts.User

  # Функция получения юзера по ID так-же получаем по current_user
  def get_user(id), do: Repo.get(User, id)

  @doc """
  Основная функция Silent Login. Принимает сырую строку initData. Комбайн входа,
  проверяет подпись, парсит данные, регистрирует или логинит пользователя.
  """
  def silent_login(init_data) do
    # Читаем токен из конфига
    bot_token = Application.get_env(:messenger, :telegram)[:bot_token]

    case verify_telegram_data(init_data, bot_token) do
      {:ok, tg_user_map} ->
        # Телеграм возвращает id как число.
        telegram_id = tg_user_map["id"]
        username = tg_user_map["username"]

        find_or_register_user(telegram_id, username)

      {:error, :invalid_signature} ->
        {:error, :unauthorized}
    end
  end

  # Ищем юзера в базе или создаем со статусом pending
  defp find_or_register_user(telegram_id, username) do
    case Repo.get_by(User, telegram_id: telegram_id) do
      %User{} = user ->
        {:ok, :logged_in, user}

      nil ->
        attrs = %{telegram_id: telegram_id, username: username, role: "pending"}

        case %User{}
             |> User.changeset(attrs)
             |> Repo.insert() do
          {:ok, new_user} -> {:ok, :registered_pending, new_user}
          {:error, changeset} -> {:error, changeset}
        end
    end
  end

  @doc """
  Криптографическая проверка подписи Telegram.
  Алгоритм строго по документации Telegram Mini Apps.
  """
  def verify_telegram_data(init_data, bot_token) do
    # Парсим URL-query строку в мапу (key-value)
    params = URI.decode_query(init_data)

    # Вытаскиваем хэш, который прислал телеграм для проверки
    provided_hash = Map.get(params, "hash")

    # Готовим строку, сортируем ключи по алфавиту, исключая hash)
    data_check_string =
      params

      |> Map.drop(["hash"])
      |> Enum.sort()
      |> Enum.map(fn {k, v} -> "#{k}=#{v}" end)

      |> Enum.join("\n")

    # HMAC-SHA256 от константы WebAppData с ключом bot_token !!! Потом переделать на отдельную функцию!!!
    secret_key = :crypto.mac(:hmac, :sha256, "WebAppData", bot_token)

    # HMAC-SHA256 от нашей data_check_string с полученным secret_key
    calculated_hash =
      :crypto.mac(:hmac, :sha256, secret_key, data_check_string)
      |> Base.encode16(case: :lower) # Переводим в нижний регистр hex-строки

    # Сравниваем хэши. Если совпали — парсим поле user
    if calculated_hash == provided_hash do
      # Внутри initData поле user лежит как JSON-строка
      case Jason.decode(Map.get(params, "user", "{}")) do
        {:ok, user_map} -> {:ok, user_map}
        {:error, _} -> {:error, :invalid_signature}
      end
    else
      {:error, :invalid_signature}
    end
  end
end
