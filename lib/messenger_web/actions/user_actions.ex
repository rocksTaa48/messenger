defmodule MessengerWeb.Actions.UserActions do
  import Phoenix.Channel, only: [push: 3]
  import Phoenix.Socket, only: [assign: 3]
  alias Messenger.Accounts
  alias Messenger.Chats
  alias Messenger.AiProfiles
  alias Messenger.Serializer

  @doc"""
  Эндпоинт для получения USAGE пользователя, отдаем конкретные данные за период на фронт
  """
  def handle_in("click_show_user_usage", payload, socket) do
    current_user = socket.assigns.current_user
    period = Map.get(payload, "period")
    case Accounts.get_user_usage_ai_models(current_user.id, period) do
      user_usage ->
        # Стейт не обновляем а только отдаем необходимое!
        {:reply, {:ok, %{
          "user_usage" => user_usage
        }},
          socket}
      {:error, reason} ->
        {:reply, {:error, %{reason: "failed_to_process_message"}}, socket}
    end

  end

end
