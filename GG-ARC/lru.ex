defmodule ARC.LRU do
  defstruct items: %{},
            order: :gb_trees.empty(),
            next: 0

  def new, do: %__MODULE__{}

  def size(%__MODULE__{items: items}), do: map_size(items)

  def empty?(list), do: size(list) == 0

  def get(%__MODULE__{items: items}, key) do
    case Map.fetch(items, key) do
      {:ok, {value, _}} -> {:ok, value}
      :error -> :miss
    end
  end

  def put(list, key, value) do
    list = delete(list, key)
    index = list.next

    %{
      list
      | items: Map.put(list.items, key, {value, index}),
        order: :gb_trees.insert(index, key, list.order),
        next: index + 1
    }
  end

  def delete(list, key) do
    case Map.pop(list.items, key) do
      {nil, _} ->
        list

      {{_value, index}, items} ->
        %{
          list
          | items: items,
            order: :gb_trees.delete(index, list.order)
        }
    end
  end

  def pop_lru(list) do
    if empty?(list) do
      :empty
    else
      {{index, key}, order} = :gb_trees.take_smallest(list.order)
      {{value, ^index}, items} = Map.pop(list.items, key)

      updated = %{list | items: items, order: order}

      {{key, value}, updated}
    end
  end

  def keys(%__MODULE__{items: items}) do
    Map.keys(items)
  end
end
