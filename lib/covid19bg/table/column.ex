defmodule Covid19bg.Table.Column do
  @enforce_keys [:title, :key]
  defstruct [
    :title,
    :key,
    summary: true,
    header_color: :red,
    color: nil,
    width: 0,
    align: :right,
    remove_if: &__MODULE__.remove_if/1,
    formatter: &__MODULE__.formatter/2
  ]

  def formatter(v, _), do: to_string(v)

  def remove_if(_), do: false
end
