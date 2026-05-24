defmodule MessengerWeb.Plugs.FetchCurrentUser do
  import Plug.Conn
  alias Messenger.Accounts

  def init(opts), do: opts

  def call(conn, _opts) do
    # Достаем user_id из сессии
    user_id = get_session(conn, :user_id)

    # Если id есть, ищем юзера, если нет — пишем nil
    cond do
      user = user_id && Accounts.get_user(user_id) ->
        assign(conn, :current_user, user) # В контроллерах доступно conn.assigns.current_user

      true ->
        assign(conn, :current_user, nil)
    end
  end
end
