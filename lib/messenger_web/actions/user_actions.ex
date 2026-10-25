defmodule MessengerWeb.Actions.UserActions do
  import Phoenix.Channel, only: [push: 3]
  import Phoenix.Socket, only: [assign: 3]
  alias Messenger.{Accounts, Chats, AiProfiles, Serializer, CreditConverter}
  require Logger

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


  @doc"""
  Вызов инвойса у ClusterPay для оплаты криптой
  """
  def handle_in("click_create_invoice", %{"amount" => amount, "network" => network}, socket) do
    current_user = socket.assigns.current_user
    custom_id = :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
    case Accounts.create_clusterpay_invoice(%{
      user_id: current_user.id,
      provider: "clusterpay",
      amount_original: amount,
      currency_original: "USDT",
      amount_credits: CreditConverter.usd_to_credits(amount),
      status: "pending",
      external_order_id: custom_id,
      metadata: %{
      "network" => network
      }
    }) do
      {:ok, payment} ->
        case push_to_clusterpay(payment) do
          {:ok, response_data} ->
            Phoenix.PubSub.broadcast(
              Messenger.PubSub,
              "user:#{current_user.id}:lobby",
              {:payment_invoice_created, %{
                payment_id: payment.id,
                payment_url: response_data.payment_url,
                exact_amount: to_string(response_data.exact_amount),
                address: response_data.address,
                network: network
              }}
            )

            {:reply, {:ok, response_data}, socket}

          {:error, _reason} ->
            {:reply, {:error, %{message: "Не удалось инициировать платеж в ClusterPay"}}, socket}
        end

      {:error, _changeset} ->
        {:reply, {:error, %{message: "Database ошибка создания инвойса"}}, socket}
    end
  end

  defp push_to_clusterpay(payment) do
    config = Application.get_env(:messenger, :clusterpay)
    network = payment.metadata["network"]
    wallet_address = config[:wallets][network]

    # Запрос к ClusterPay
    payload = %{
      amount: payment.amount_original,
      currency: payment.currency_original,
      callback_url: config[:callback_url],
      custom_id: payment.external_order_id,
      redirect_url: config[:redirect_url],
      wallets: %{to_string(network) => wallet_address}
    }

    Logger.warning("Payment for ClusterPay: #{inspect(payload)}")

    case Req.post("#{config[:base_url]}/api/v1/checkout",
           json: payload,
           headers: %{"Authorization" => "Bearer #{config[:api_key]}"}
         ) do
      {:ok, %{status: 200, body: body}} ->
        case Accounts.payment_update(payment, %{
          status: "processing",
          metadata: Map.merge(payment.metadata, %{
            "clusterpay_amount" => body["amount"],
            "payment_url" => body["payment_url"],
            "expires_at" => body["expires_at"]
          })
        }) do
          {:ok, updated_payment} ->
            {:ok, %{
              payment_id: updated_payment.id,
              payment_url: body["payment_url"],
              exact_amount: body["amount"],
              address: wallet_address
            }}

          {:error, changeset} ->
            Logger.error("Failed to Update Payment in DB: #{inspect(changeset)}")
            {:error, :db_update_failed}
        end

      {:ok, %{status: status, body: body}} ->
        Logger.error("ClusterPay API returned error status #{status}: #{inspect(body)}")
        {:error, :api_error}

      {:error, reason} ->
        Logger.error("Failed to connect ClusterPay: #{inspect(reason)}")
        {:error, :network_error}
    end
  end

end