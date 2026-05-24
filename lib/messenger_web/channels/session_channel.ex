defmodule MessengerWeb.SessionChannel do
  # Этот модуль является каналом
  use MessengerWeb, :channel

  @doc """
  Сюда пользователь заходит через channel("session:presence")
  """
  def join("session:presence", _payload, socket) do
    # Извлекаем пользователя, которого мы сохранили в UserSocket
    current_user = socket.assigns.current_user

    # Пакет данных для фронтенда
    user_data = %{
      id: current_user.id,
      telegram_id: current_user.telegram_id,
      username: current_user.username,
      first_name: current_user.first_name,
      role: current_user.role
    }

    # Возвращаем стандартный кортеж канала
    {:ok, %{user: user_data}, socket}
  end
end
