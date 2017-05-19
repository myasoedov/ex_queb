defmodule ExQueb.StringFilters do
  @moduledoc """
  Build Filters for String Fields.

  String fields can be filtered by the following:

  * begins with
  * ends with
  * contains
  * equals
  """
  import Ecto.Query

  @doc """
  Build a string filter.
  """

  defp build_filter(builder, field, value, :begins_with) do
    match = String.downcase(value) <> "%"
    where(builder, [q], like(fragment("LOWER(?)", field(q, ^field)), ^match))
  end

  defp build_filter(builder, field, value, :ends_with) do
    match = "%" <> String.downcase(value)
    where(builder, [q], like(fragment("LOWER(?)", field(q, ^field)), ^match))
  end

  defp build_filter(builder, field, value, :contains) do
    match = "%" <> String.downcase(value) <> "%"
    where(builder, [q], like(fragment("LOWER(?)", field(q, ^field)), ^match))
  end

  defp build_filter(builder, field, value, :equals) do
    where(builder, [q], fragment("LOWER(?)", field(q, ^field)) == fragment("LOWER(?)", ^value))
  end

  defp build_filter(builder, field, value, _) do
    where(builder, [q], fragment("LOWER(?)", field(q, ^field)) == fragment("LOWER(?)", ^value))
  end
end
