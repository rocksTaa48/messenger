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
        # Собираем все пришедшие параметры для создания/обновления
        attrs = %{
          telegram_id: telegram_id,
          username: tg_user_map["username"],
          first_name: tg_user_map["first_name"],
          last_name: tg_user_map["last_name"],
          # Сохраняем весь сырой map, полученный от Telegram
          raw_data: tg_user_map
        }

        find_and_sync_user(telegram_id, attrs)

      {:error, :invalid_signature} ->
        {:error, :unauthorized}
    end
  end

  defp find_and_sync_user(telegram_id, attrs) do
    case Repo.get_by(User, telegram_id: telegram_id) do
      %User{} = user ->
        # Если пользователь существует, обновляем его attrs
        case user

             |> User.changeset(attrs)
             |> Repo.update() do
          {:ok, updated_user} -> {:ok, :logged_in, updated_user}
          {:error, changeset} -> {:error, changeset}
        end

      nil ->
        # Если пользователя нет. При первой регистрации жестко задаем роль "pending"
        ai_model = Messenger.AiProfiles.get_default_user_ai_model("free")
        registration_attrs = Map.merge(attrs, %{role: "pending", status: "free", ai_model_id: ai_model.id})
        case %User{}

             |> User.changeset(registration_attrs)
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
