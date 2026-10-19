defmodule Messenger.CreditConverter do
  @moduledoc """
  Единственный источник правды USD <-> Credits.
  Внутри БД всё в USD (Decimal). Наружу (в API) — кредиты. Пользователю никогда не отдаем сумму в USD
  """
  # 1 credit = $0.01 => 100 credits = $1
  @credits_per_usd 100

  def credits_per_usd, do: @credits_per_usd

  @doc """
  USD -> credits как Decimal(2).
  Не целые, потому что Whisper ($0.006/мин) иначе схлопнется в 0 или 1 credit.
  """
  def usd_to_credits(nil), do: Decimal.new("0.00")
  def usd_to_credits(%Decimal{} = usd) do
    usd
    |> Decimal.mult(@credits_per_usd)
    |> Decimal.round(2, :half_up)
  end
  def usd_to_credits(usd), do: usd_to_credits(Decimal.new(to_string(usd)))

  @doc """
  credits -> USD (для админки, ручных операций).
  """
  def credits_to_usd(%Decimal{} = c), do: Decimal.div(c, @credits_per_usd)
  def credits_to_usd(c), do: credits_to_usd(Decimal.new(to_string(c)))
  def to_api(%Decimal{} = d), do: Decimal.to_string(d, :normal)
end