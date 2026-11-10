defmodule GGARC.Server do
  use GenServer

  alias GGARC.{Algorithm, State}

  def start_link(opts) do
    capacity = Keyword.fetch!(opts, :capacity)

    GenServer.start_link(
      __MODULE__,
      capacity,
      Keyword.take(opts, [:name])
    )
  end

  @impl true
  def init(capacity) do
    {:ok, State.new(capacity)}
  end

  @impl true
  def handle_call({:get, key}, _from, state) do
    {result, state} = Algorithm.get(state, key)

    {:reply, result, state}
  end

  @impl true
  def handle_call({:put, key, value}, _from, state) do
    state = Algorithm.put(state, key, value)

    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:delete, key}, _from, state) do
    state = Algorithm.delete(state, key)

    {:reply, :ok, state}
  end

  @impl true
  def handle_call(:stats, _from, state) do
    {:reply, Algorithm.stats(state), state}
  end
end
