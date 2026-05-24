defmodule MessengerWeb.SessionController do

#  use MessengerWeb, :controller
#  alias Messenger.Accounts

#  def telegram_login(conn, %{"initData" => init_data}) do
#    case Accounts.silent_login(init_data) do

#      {:ok, :logged_in, user} ->
#      conn
#      |> configure_session(renew: true)
#      |> put_session(:user_id, user.id)
#      |> put_status(:ok)
#      |> json(%{status: "success", app_status: user_status})

#      {:ok, :registration_pending, user} ->
#      conn
#      |> configure_session(renew: true)
#      |> put_session(:user_id, user.id)
#      |> put_status(:created)
#      |> json(%{status: "pending_verification", app_status: user.status})

#      {:error, :unauthorized} ->
#      conn
#      |> put_status(:unauthorized)
#      |> json(%{error: "Fake Telegram data detected"})

#    end
#  end
end