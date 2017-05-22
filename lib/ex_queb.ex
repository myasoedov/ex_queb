defmodule ExQueb do
  @moduledoc """
  Build Ecto filter Queries.
  """
  import Ecto.Query
  require Logger

  @doc """
  Create the filter

  Uses the :q query parameter to build the filter.
  @options is a map with additional parameters like following:
    scopes: list of typles {scope_name, fn/2} for custom filtering
  """
  def filter(query, params, options \\ %{}) do
    params[Application.get_env(:ex_queb, :filter_param, :q)]
    |> prepare_filters()
    |> apply_filters(query, options)
  end

  defp prepare_filters(nil), do: []
  defp prepare_filters(filters) do
    Map.to_list(filters)
    |> Enum.filter(&(not elem(&1,1) in ["", nil]))
    |> Enum.map(&({Atom.to_string(elem(&1, 0)), elem(&1, 1)}))
  end

  defp apply_filters(filters, query, options) do
    Enum.reduce(filters, query, fn({filter, value}, query) ->
      case Regex.run(~r/^(.+)_([\w]+)$/, filter) do
      [_, field, "scope"] -> find_scope_in_options(options, field)
                             |> build_scope_filter(query, value)
      [_, field, matcher] -> build_filter(query, String.to_atom(field), value, String.to_atom(matcher))
      _ ->
        Logger.info "can't match filter #{filter}... skipping"
        query
      end
    end)
  end

  defp find_scope_in_options(%{scopes: scopes}, field) do
    {_, scope} = Enum.find(scopes, fn ({name, _}) -> field == "#{name}" end)
    scope
  end
  defp find_scope_in_options(_, _), do: nil

  defp build_scope_filter(nil, query, _), do: query
  defp build_scope_filter(scope, query, value), do: scope.(query, value)

  # UUID filter
  defp build_filter(query, fld, value, :uuideq) do
    case Ecto.UUID.cast(value) do
      {:ok, uuid} -> where(query, [q], field(q, ^fld) == ^uuid)
      _ -> query
    end
  end

  # Numerical filters
  defp build_filter(query, fld, value, :eq) do
    where(query, [q], field(q, ^fld) == ^value)
  end
  defp build_filter(query, fld, value, :lt) do
    where(query, [q], field(q, ^fld) < ^value)
  end
  #defp build_filter(query, fld, value, :gte) do
  #  where(query, [q], field(q, ^fld) >= ^value)
  #end
  #defp build_filter(query, fld, value, :lte) do
  #  where(query, [q], field(q, ^fld) <= ^value)
  #end
  defp build_filter(query, fld, value, :gt) do
    where(query, [q], field(q, ^fld) > ^value)
  end

  # String filters
  defp build_filter(builder, field, value, :beginswith) do
    match = String.downcase(value) <> "%"
    where(builder, [q], like(fragment("LOWER(?)", field(q, ^field)), ^match))
  end

  defp build_filter(builder, field, value, :endswith) do
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

  # Date filters
  defp build_filter(query, fld, value, :gte) do
    where(query, [q], fragment("? >= ?", field(q, ^fld), type(^cast_date_time(value), Ecto.DateTime)))
  end
  defp build_filter(query, fld, value, :lte) do
    where(query, [q], fragment("? <= ?", field(q, ^fld), type(^cast_date_time(value), Ecto.DateTime)))
  end

  # Unknown
  defp build_filter(query, _, _, matcher) do
    Logger.warn "unknown matcher #{matcher}... skipping"
    query
  end

  defp cast_date_time(value) do
    {:ok, date} = Ecto.Date.cast(value)
    date
    |> Ecto.DateTime.from_date
    |> Ecto.DateTime.to_string
  end

  @doc """
  Build order for a given query.
  """
  def build_order_bys(query, opts, action, params) when action in ~w(index csv)a do
    case Keyword.get(params, :order, nil) do
      nil ->
        build_default_order_bys(query, opts, action, params)
      order ->
        case get_sort_order(order) do
          nil ->
            build_default_order_bys(query, opts, action, params)
          {name, sort_order} ->
            name_atom = String.to_existing_atom name
            if sort_order == "desc" do
              order_by query, [c], [desc: field(c, ^name_atom)]
            else
              order_by query, [c], [asc: field(c, ^name_atom)]
            end

        end
    end
  end
  def build_order_bys(query, _, _, _), do: query

  defp build_default_order_bys(query, opts, action, _params) when action in ~w(index csv)a do
    case query.order_bys do
      [] ->
        index_opts = Map.get(opts, action, []) |> Enum.into(%{})
        {order, primary_key} = get_default_order_by_field(query, index_opts)
        order_by(query, [c], [{^order, field(c, ^primary_key)}])
      _ -> query
    end
  end
  defp build_default_order_bys(query, _opts, _action, _params), do: query

  @doc """
  Get the sort order for a params entry.
  """
  def get_sort_order(nil), do: nil
  def get_sort_order(order) do
    case Regex.scan ~r/(.+)_(desc|asc)$/, order do
      [] -> nil
      [[_, name, sort_order]] -> {name, sort_order}
    end
  end

  defp get_default_order_by_field(_query, %{default_sort: [{order, field}]}) do
    {order, field}
  end
  defp get_default_order_by_field(query, %{default_sort_order: order}) do
    {order, get_default_order_by_field(query)}
  end
  defp get_default_order_by_field(_query, %{default_sort_field: field}) do
    {:desc, field}
  end
  defp get_default_order_by_field(query, _) do
    {:desc, get_default_order_by_field(query)}
  end

  defp get_default_order_by_field(query) do
    case query do
      %{from: {_, mod}} ->
        case mod.__schema__(:primary_key) do
          [name |_] -> name
          _ -> mod.__schema__(:fields) |> List.first
        end
      _ -> :id
    end
  end
end
