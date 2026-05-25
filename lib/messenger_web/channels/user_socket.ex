defmodule MessengerWeb.UserSocket do
  use Phoenix.Socket
  alias Messenger.Accounts


  channel "session:*", MessengerWeb.SessionChannel

  @doc """
  Делаю функцию connect/3 сюда с фронта полетят параметры первого рукопожатия
  """

  def connect(params, socket, _connect_info) do
    init_data = Map.get(params, "initData")

    case init_data do
      nil ->
      # Защита от пустой initData, падаем с ошибкой сразу, до вызова контекста
      :error
      init_data ->

      # Вызываем метод из контекста Accounts
      case Accounts.silent_login(init_data) do
        # Сценарий A: Пользователь имеется и успешно вошел
        {:ok, :logged_in, user} ->
          # Кладем структуру пользователя в сокет, чтобы каналы имели к ней доступ
          authorized_socket = assign(socket, :current_user, user)
          {:ok, authorized_socket}

        # Сценарий B: Пользователь новый и успешно зарегистрирован в базе
        {:ok, :registered_pending, new_user} ->
          # Точно так же пускаем его и сохраняем данные в сокет
          authorized_socket = assign(socket, :current_user, new_user)
          {:ok, authorized_socket}

        # Сценарий C: Хэш не совпал
        {:error, _reason} ->
          # Закрываем соединение reject unauthorized connection
          :error
      end
    end
  end
  @doc """
  Идентификатор сокета.
  """

  def id(socket) do
    "user_socket:#{socket.assigns.current_user.id}"
  end
end