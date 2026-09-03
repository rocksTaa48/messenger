defmodule Messenger.Chats.AiStreamer do
  @moduledoc """
  Фоновый воркер, который живет в памяти сервера отдельно от вебсокета, управляет стримом и шлет батчи текста
  в персональное лобби пользователя. После получения последней порции, выполняет финальную запись в БД.
  """
  alias Messenger.Chats
  alias Messenger.Repo

  @doc """
  Запускает изолированный Task под управлением DynamicSupervisor.
  """
  def start_streaming(user_id, ai_profile, chat, message, context) do
    DynamicSupervisor.start_child(
      Messenger.AiSupervisor,
      {Task, fn -> process_stream(user_id, ai_profile, chat, message, context) end}
    )
  end

  # Внутренний процесс стриминга
  defp process_stream(user_id, ai_profile, chat, message, context) do
    url = "https://openrouter.ai/api/v1/chat/completions"
    api_key = Application.get_env(:messenger, :ai_providers)[:openrouter_api_key]

    body = %{
      model: ai_profile.openrouter_model_id,
      messages: context ++ [%{role: "user", content: message.content}],
      temperature: ai_profile.temperature,
      top_p: ai_profile.top_p,
      frequency_penalty: ai_profile.frequency_penalty,
      presence_penalty: ai_profile.presence_penalty,
      max_completion_tokens: ai_profile.max_completion_tokens,
      stream: true
    }

    # Инициализируем аккумулятор как map: text, usage
    initial_acc = %{text: "", usage: nil}

    # Колбэк-функция для Req
    stream_handler = fn {:data, chunk}, acc ->
      case parse_sse_chunk(chunk) do
        {:tokens, list_of_tokens, usage} ->
          chunk_text = Enum.join(list_of_tokens, "")
          new_text = acc.text <> chunk_text
          # Если usage пришёл в этом чанке – обновляем
          new_usage = usage || acc.usage

          # Отправляем токены клиенту
          Phoenix.PubSub.broadcast(
            Messenger.PubSub,
            "user:#{user_id}:lobby",
            {:ai_token, %{chat_id: message.chat_id, token: chunk_text}}
          )

          {:cont, %{text: new_text, usage: new_usage}}

        {:done, usage} ->
          # В последнем чанке может быть usage
          new_usage = usage || acc.usage
          {:cont, %{acc | usage: new_usage}}

        :empty ->
          {:cont, acc}
      end
    end

    # Запускаем POST-запрос через Req
    case Req.post(url,
           json: body,
           auth: {:bearer, api_key},
           finch: Messenger.OpenRouterFinch,
           into: {initial_acc, stream_handler},
           headers: [
             {"HTTP-Referer", "https://your-monorepo-app.com"},
             {"X-Title", "Phoenix Svelte Chat"}
           ],
           receive_timeout: 10_000
         ) do

      {:ok, %Req.Response{status: 200, body: final_acc}} ->
        # final_acc – карта с полями text и usage
        # Сохраняем сообщение ассистента с метриками
        usage = final_acc.usage || %{"prompt_tokens" => 0, "completion_tokens" => 0, "total_tokens" => 0}

        {:ok, _ai_message} = Chats.create_assistant_message(%{
          chat_id: message.chat_id,
          content: final_acc.text,
          role: "assistant",
          prompt_tokens: usage["prompt_tokens"],
          completion_tokens: usage["completion_tokens"],
          total_tokens: usage["total_tokens"]
        })

        Phoenix.PubSub.broadcast(
          Messenger.PubSub,
          "user:#{user_id}:lobby",
          {:ai_stream_done, %{chat_id: message.chat_id}}
        )

      {:error, %Finch.Error{reason: :timeout}} ->
        send_error_to_lobby(user_id, message.chat_id, "Сервер перегружен, попробуйте позже")

      error ->
        IO.inspect(error, label: "OpenRouter Stream Error")
        send_error_to_lobby(user_id, message.chat_id, "Ошибка генерации текста")
    end
  end

  defp send_error_to_lobby(user_id, chat_id, reason) do
    Phoenix.PubSub.broadcast(
      Messenger.PubSub,
      "user:#{user_id}:lobby",
      {:ai_stream_error, %{chat_id: chat_id, reason: reason}}
    )
  end

  # Парсер SSE нам возвращает:
  # - {:tokens, list, usage} – если есть токены и возможно usage
  # - {:done, usage} – если встретили [DONE] (может содержать usage)
  # - :empty – если нет токенов
  defp parse_sse_chunk(chunk) do
    lines = String.split(chunk, "\n")
    {tokens, usage} =
      Enum.reduce(lines, {[], nil}, fn line, {acc_tokens, acc_usage} ->
        cond do
          String.starts_with?(line, "data: [DONE]") ->
            # В этом же чанке может быть usage в предыдущей строке, но мы его уже обработали
            {acc_tokens, acc_usage}

          String.starts_with?(line, "data: ") ->
            json_str = String.replace_prefix(line, "data: ", "") |> String.trim()

            case Jason.decode(json_str) do
              {:ok, data} ->
                # Извлекаем токен
                new_tokens =
                  case get_in(data, ["choices", Access.at(0), "delta", "content"]) do
                    nil -> acc_tokens
                    content -> [content | acc_tokens]
                  end

                # Извлекаем usage, если есть
                new_usage =
                  case get_in(data, ["usage"]) do
                    nil -> acc_usage
                    usage_data -> usage_data
                  end

                {new_tokens, new_usage}

              _ ->
                {acc_tokens, acc_usage}
            end

          true ->
            {acc_tokens, acc_usage}
        end
      end)

    cond do
      String.contains?(chunk, "[DONE]") ->
        {:done, usage}
      Enum.empty?(tokens) ->
        :empty
      true ->
        {:tokens, Enum.reverse(tokens), usage}
    end
  end
end