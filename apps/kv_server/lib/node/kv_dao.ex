defmodule KVServer.Dao do

  def perform(:create, table) do
    KVStore.Router.route_all(:no_transaction, :create, {table})
  end

  def perform(:put, table, key, value) do
    KVStore.Router.route_all(:no_transaction, :put, {table, key, value})
  end

  def perform(:get, table, key) do
    KVStore.Router.route_all(:no_transaction, :get, {table, key})
  end

  def perform(:delete, table, key) do
    KVStore.Router.route_all(:no_transaction, :delete, {table, key})
  end

end
