defmodule BittorrentClient.Torrent.Peer.State do
  @moduledoc """
  credit to https://github.com/unblevable/T.rex/blob/master/lib/trex/peer.ex
  			https://glot.io/snippets/e6zq7yv67l
  Mangages peer state, eases TCP connection handling
  """
  @behaviour :gen_fsm
  require Logger

  def start_link(pworker_pid) do
    :gen_fsm.start_link(__MODULE__, pworker_pid, [])
  end

  def init(pworker_pid) do
    {:ok, :we_choke, pworker_pid}
  end

  def me_choke(pworker_pid) do
    :gen_fsm.send_event(pworker_pid, :me_choke)
  end

  def me_interest(pworker_pid) do
    :gen_fsm.send_event(pworker_pid, :me_interest)
  end

  def it_choke(pworker_pid) do
    :gen_fsm.send_event(pworker_pid, :it_choke)
  end

  def it_interest(pworker_pid) do
    :gen_fsm.send_event(pworker_pid, :it_interest)
  end


  @doc """
  This client is choking the given peer and vice-versa.
  """
  def we_choke(:me_interest, state) do
    {:next_state, :me_interest_it_choke, state}
  end

  def we_choke(:it_interest, state) do
    {:next_state, :me_choke_it_interest, state}
  end

  @doc """
  This client is interested in the given peer and vice-versa.
  """
  def we_interest(:me_choke, state) do
    {:next_state, :me_choke_it_interest, state}
  end

  def we_interest(:it_choke, state) do
    {:next_state, :me_interest_it_choke, state}
  end

  def we_interest(:have, state) do
    {:next_state, :we_interest, state}
  end

  @doc """
  This client is choking the given peer, but the peer is interested in the
  client.
  """
  def me_choke_it_interest(:me_interest, state) do
    {:next_state, :we_interest, state}
  end

  def me_choke_it_interest(:it_choke, state) do
    {:next_state, :we_choke, state}
  end

  @doc """
  This client is interested in the given peer, but the peer is choking the
  client.
  """
  def me_interest_it_choke(:me_choke, state) do
    {:next_state, :we_choke, state}
  end

  def me_interest_it_choke(:it_interest, state) do
    {:next_state, :we_interest, state}
  end

  ## Callbacks ===============================================================
  def handle_event(event, state_name, state_data) do
    {:stop, {:bad_event, state_name, event}, state_data}
  end

  def handle_sync_event(event, _from, state_name, state_data) do
    {:stop, {:bad_sync_event, state_name, event}, state_data}
  end

  def handle_info(_msg, state_name, state_data) do
    {:next_state, state_name, state_data}
  end

  def terminate(_reason, _state_name, _state_data) do
    :ok
  end

  def code_change(_old, state_name, state_data, _extra) do
    {:ok, state_name, state_data}
  end
end
