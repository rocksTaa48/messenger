defmodule Messenger.Chats.PayloadParams do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  @allowed_actions ~w(update_title toggle_pin delete)
  @max_override_keys 10
  @override_spec %{
    "temperature"       => {:float, 0.0, 2.0},
    "top_p"             => {:float, 0.0, 1.0},
    "frequency_penalty" => {:float, -2.0, 2.0},
    "presence_penalty"  => {:float, -2.0, 2.0}
  }
  embedded_schema do
    field :text, :string
    field :title, :string
    field :message_id, :integer
    field :chat_id, :integer
    field :group_id, :integer
    field :action, :string
    field :temp_id, :string
    field :ai_model_id, :integer
    field :image_ai_model_id, :integer
    field :is_audio, :boolean, default: false
    field :format, :string
    field :base64, :string
    field :is_image_session, :boolean, default: false
    field :ai_transcript_model_id, :integer
    field :profile_overrides, :map, default: %{}
  end

  def build(raw_payload) do
    %__MODULE__{}
    |> cast(raw_payload || %{}, [
      :temp_id,
      :is_audio,
      :message_id,
      :image_ai_model_id,
      :text,
      :title,
      :action,
      :chat_id,
      :group_id,
      :base64,
      :format,
      :ai_model_id,
      :ai_transcript_model_id,
      :is_image_session,
      :profile_overrides
    ])
    |> update_change(:profile_overrides, &sanitize_overrides/1)
    |> validate_number(:chat_id, greater_than: 0)
    |> validate_number(:group_id, greater_than: 0)
    |> validate_number(:message_id, greater_than: 0)
    |> validate_number(:ai_model_id, greater_than: 0)
    |> validate_number(:ai_transcript_model_id, greater_than: 0)
    |> validate_length(:base64, max: 14_000_000, message: "base64 too large (max ~10MB decoded)")
    |> validate_inclusion(:action, @allowed_actions, message: "unknown_action")
    |> apply_action(:validate) # Возвращает {:ok, %MessageParams{}} при удаче или {:error, changeset} при ошибке
  end

  #=================================================
  #---------------SANITIZE OVERRIDES----------------
  #=================================================
  defp sanitize_overrides(raw) when is_map(raw) do
    limited_raw = raw |> Enum.take(@max_override_keys) |> Map.new()

    Enum.reduce(@override_spec, %{}, fn {key, spec}, acc ->
      with {:ok, value} <- Map.fetch(limited_raw, key),
           {:ok, v} <- value_override(spec, value) do
        Map.put(acc, key, v)
      else
        _ -> acc
      end
    end)
  end

  defp sanitize_overrides(_), do: %{}

  defp value_override({:float, min, max}, v) when is_number(v) do
    f = Float.round(v * 1.0, 2)
    if f >= min and f <= max, do: {:ok, f}, else: :drop
  end

  defp value_override({:float, min, max}, v) when is_binary(v) do
    case Float.parse(v) do
      {f, ""} ->
        f = Float.round(f, 2)
        if f >= min and f <= max, do: {:ok, f}, else: :drop
      _ -> :drop
    end
  end

  defp value_override(_spec, _v), do: :drop
end