defmodule MessengerWeb.Plugs.FetchTelegramUser do
  import Plug.Conn
  require Logger
  alias Messenger.Accounts

  def init(opts), do: opts

  def call(conn, _opts) do
    with ["Bearer " <> init_data] <- get_req_header(conn, "authorization"),
         {:ok, _status, user} <- Accounts.silent_login(init_data) do
      # Если всё ок, кладем юзера в коннект (как assign в сокете)
      assign(conn, :current_user, user)
    else
      _error ->
        # Если заголовка нет или хэш не совпал
        Logger.warning("API: Ошибка авторизации Telegram пользователя")

        conn
        |> put_status(:unauthorized)
        |> phoenix_json(%{error: "Unauthorized"})
        |> halt() # Останавливаем дальнейшее выполнение запроса
    end
  end

  # Локальный хелпер, чтобы не тянуть лишние зависимости для JSON
  defp phoenix_json(conn, data) do
    conn
    |> put_resp_content_type("application/json")

    |> send_resp(conn.status || 200, Jason.encode!(data))
  end
end
