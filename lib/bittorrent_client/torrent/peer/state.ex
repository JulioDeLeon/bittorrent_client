defmodule BittorrentClient.Torrent.Peer.State do
  @moduledoc """
  credit to https://github.com/unblevable/T.rex/blob/master/lib/trex/peer.ex
  			https://glot.io/snippets/e6zq7yv67l
  Mangages peer state, eases TCP connection handling
  """
  use GenStateMachine
  require Logger

  def start_link do
    # no need to take in data ATM
    GenStateMachine.start_link(__MODULE__, {:we_choke, []})
  end

  # Client calls
  def me_choke(pid) do
    GenStateMachine.cast(pid, :me_choke)
  end

  def it_choke(pid) do
    GenStateMachine.cast(pid, :it_choke)
  end

  def me_interest(pid) do
    GenStateMachine.cast(pid, :me_interest)
  end

  def it_interest(pid) do
    GenStateMachine.cast(pid, :it_interest)
  end

  # Server callbacks
  def handle_event(:cast, :me_interest, :we_choke, peer_data) do
    {:next_state, :me_interest_it_choke, peer_data}
  end

  def handle_event(:cast, :it_interest, :we_choke, peer_data) do
    {:next_state, :me_choke_it_interest, peer_data}
  end

  def handle_event(:cast, :me_choke, :me_interest_it_choke, peer_data) do
    {:next_state, :we_choke, peer_data}
  end

  def handle_event(:cast, :it_choke, :me_choke_it_interest, peer_data) do
    {:next_state, :we_choke, peer_data}
  end

  def handle_event(:cast, :me_interest, :me_choke_it_interest, peer_data) do
    {:next_state, :we_interest, peer_data}
  end

  def handle_event(:cast, :it_interest, :me_interest_it_choke, peer_data) do
    {:next_state, :we_interest, peer_data}
  end

  def handle_event(:cast, :me_choke, :we_interest, peer_data) do
    {:next_state, :me_choke_it_interest, peer_data}
  end

  def handle_event(:cast, :it_choke, :we_interest, peer_data) do
    {:next_state, :me_interest_it_choke, peer_data}
  end

  def handle_event(:cast, :have, :we_interest, peer_data) do
    {:next_state, :we_interest, peer_data}
  end
end
