defmodule GGARC.Cache do
  alias GGARC.Server

  def start_link(opts) do
    Server.start_link(opts)
  end

  def get(server, key) do
    GenServer.call(server, {:get, key})
  end

  def put(server, key, value, metadata) do
    GenServer.call(server, {:put, key, value, metadata})
  end

  def delete(server, key) do
    GenServer.call(server, {:delete, key})
  end

  def stats(server) do
    GenServer.call(server, :stats)
  end
end
