require Logger

defmodule BitcoinStream.Mempool do
  @moduledoc """
  GenServer for retrieving and maintaining mempool info
  Used for tracking mempool count, and maintaining an :ets cache of transaction prevouts

  Transaction lifecycle:
    Register -> a ZMQ sequence 'A' message received with this txid
    Insert -> a ZMQ rawtx message is received
    Drop -> EITHER a ZMQ sequence 'R' message is received
         -> OR the transaction is included in a ZMQ rawblock message

    ZMQ 'A' and 'R' messages are guaranteed to arrive in order relative to each other
    but rawtx and rawblock messages may arrive in any order
  """
  use GenServer

  alias BitcoinStream.Protocol.Transaction, as: BitcoinTx
  alias BitcoinStream.RPC, as: RPC

  @doc """
  Start a new mempool tracker,
  connecting to a bitcoin node at RPC `host:port` for ground truth data
  """
  def start_link(opts) do
    Logger.info("Starting Mempool Tracker");
    # cache of all transactions in the node mempool, mapped to {inputs, total_input_value}
    :ets.new(:mempool_cache, [:set, :public, :named_table]);
    # cache of transactions ids in the mempool, but not yet synchronized with the :mempool_cache
    :ets.new(:sync_cache, [:set, :public, :named_table]);
    # cache of transaction ids included in the last block
    # used to avoid allowing confirmed transactions back into the mempool if rawtx events arrive late
    :ets.new(:block_cache, [:set, :public, :named_table]);

     # state: {count, sequence_number, queue, done, blocklock}
    GenServer.start_link(__MODULE__, {0, :infinity, [], false, false}, opts)
  end

  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  def handle_call(:get_count, _from, {count, seq, queue, done, blocklock}) do
    {:reply, count, {count, seq, queue, done, blocklock}}
  end

  @impl true
  def handle_call({:set_count, n}, _from, {_count, seq, queue, done, blocklock}) do
    {:reply, :ok, {n, seq, queue, done, blocklock}}
  end

  @impl true
  def handle_call(:increment_count, _from, {count, seq, queue, done, blocklock}) do
    {:reply, :ok, {count + 1, seq, queue, done, blocklock}}
  end

  @impl true
  def handle_call(:decrement_count, _from, {count, seq, queue, done, blocklock}) do
    {:reply, :ok, {count - 1, seq, queue, done, blocklock}}
  end

  @impl true
  def handle_call(:get_seq, _from, {count, seq, queue, done, blocklock}) do
    {:reply, seq, {count, seq, queue, done, blocklock}}
  end

  @impl true
  def handle_call({:set_seq, seq}, _from, {count, _seq, queue, done, blocklock}) do
    {:reply, :ok, {count, seq, queue, done, blocklock}}
  end

  @impl true
  def handle_call(:get_queue, _from, {count, seq, queue, done, blocklock}) do
    {:reply, queue, {count, seq, queue, done, blocklock}}
  end

  @impl true
  def handle_call({:set_queue, queue}, _from, {count, seq, _queue, done, blocklock}) do
    {:reply, :ok, {count, seq, queue, done, blocklock}}
  end

  @impl true
  def handle_call({:enqueue, txid}, _from, {count, seq, queue, done, blocklock}) do
    {:reply, :ok, {count, seq, [txid | queue], done, blocklock}}
  end

  @impl true
  def handle_call(:is_done, _from, {count, seq, queue, done, blocklock}) do
    {:reply, done, {count, seq, queue, done, blocklock}}
  end

  @impl true
  def handle_call(:set_done, _from, {count, seq, queue, _done, blocklock}) do
    {:reply, :ok, {count, seq, queue, true, blocklock}}
  end

  @impl true
  def handle_call(:is_block_locked, _from, {count, seq, queue, done, blocklock}) do
    {:reply, blocklock, {count, seq, queue, done, blocklock}}
  end

  @impl true
  def handle_call({:set_block_locked, lock}, _from, {count, seq, queue, done, _blocklock}) do
    {:reply, :ok, {count, seq, queue, done, lock}}
  end

  def set(pid, n) do
    GenServer.call(pid, {:set_count, n})
  end

  def get(pid) do
    GenServer.call(pid, :get_count)
  end

  defp increment(pid) do
    GenServer.call(pid, :increment_count)
  end

  defp decrement(pid) do
    GenServer.call(pid, :decrement_count)
  end

  defp get_seq(pid) do
    GenServer.call(pid, :get_seq)
  end

  defp set_seq(pid, seq) do
    GenServer.call(pid, {:set_seq, seq})
  end

  defp get_queue(pid) do
    GenServer.call(pid, :get_queue, 60000)
  end

  defp set_queue(pid, queue) do
    GenServer.call(pid, {:set_queue, queue})
  end

  defp enqueue(pid, txid) do
    GenServer.call(pid, {:enqueue, txid})
  end

  def is_done(pid) do
    GenServer.call(pid, :is_done)
  end

  defp set_done(pid) do
    GenServer.call(pid, :set_done)
  end

  def is_block_locked(pid) do
    GenServer.call(pid, :is_block_locked)
  end

  def set_block_locked(pid, lock) do
    GenServer.call(pid, {:set_block_locked, lock})
  end

  def get_tx_status(_pid, txid) do
    case :ets.lookup(:mempool_cache, txid) do
      # new transaction, not yet registered
      [] ->
        case :ets.lookup(:block_cache, txid) do
          # not included in the last block
          [] -> :new

          # already included in the last block
          [_] -> :block
        end

      # new transaction, id already registered
      [{_txid, nil, :ready}] ->
        :registered

      # already dropped
      [{_, nil, :drop}] ->
        :dropped

      # duplicate (ignore)
      [_] ->
        :duplicate
    end
  end

  def insert(pid, txid, txn) do
    case get_tx_status(pid, txid) do
      # new transaction, id already registered
      :registered ->
        with [] <- :ets.lookup(:block_cache, txid) do # double check tx isn't included in the last block
          :ets.insert(:mempool_cache, {txid, { txn.inputs, txn.value + txn.fee, txn.inflated }, nil});
          cache_spends(txid, txn.inputs);
          get(pid)
        else
          _ ->
            false
        end

      # new transaction, not yet registered
      :new ->
        :ets.insert(:mempool_cache, {txid, nil, txn})
        false

      # new transaction, already included in the last block
      :block -> false

      # already dropped
      :dropped ->
        :ets.delete(:mempool_cache, txid);
        false

      # duplicate (ignore)
      :duplicate ->
        false
    end
  end

  def register(pid, txid, sequence, do_count) do
    cond do
      # mempool isn't loaded yet - add this tx to the queue
      (get_seq(pid) == :infinity) ->
        enqueue(pid, {txid, sequence});
        false

      ((sequence == nil) or (sequence >= get_seq(pid))) ->
        case :ets.lookup(:mempool_cache, txid) do
          # new transaction
          [] ->
            with [] <- :ets.lookup(:block_cache, txid) do # double check tx isn't included in the last block
              :ets.insert(:mempool_cache, {txid, nil, :ready});
              :ets.delete(:sync_cache, txid);
              if do_count do
                increment(pid);
              end
            else
              _ -> false;
            end
            false

          # duplicate sequence message (should never happen)
          [{_txid, _, :ready}] -> false

          # already dropped
          [{_txid, _, :drop}] -> false

          # data already received, but tx not registered
          [{_txid, _, txn}] when txn != nil ->
            :ets.insert(:mempool_cache, {txid, { txn.inputs, txn.value + txn.fee, txn.inflated }, nil});
            :ets.delete(:sync_cache, txid);
            cache_spends(txid, txn.inputs);
            if do_count do
              increment(pid);
            end
            {txn, get(pid)}

          # some other invalid state (should never happen)
          [_] -> false
        end

      true -> false
    end
  end

  def drop(pid, txid) do
    case :ets.lookup(:mempool_cache, txid) do
      # tx not yet registered
      [] ->
        case :ets.lookup(:sync_cache, txid) do
          [] -> false

          # tx is in the mempool sync cache, mark to be dropped when processed
          _ ->
            :ets.insert(:mempool_cache, {txid, nil, :drop});
            decrement(pid);
            get(pid)
        end

      # already marked as dropped (should never happen)
      [{_txid, nil, :drop}] -> false

      # tx registered but not processed, mark to be dropped
      [{_txid, nil, :ready}] ->
        :ets.insert(:mempool_cache, {txid, nil, :drop});
        decrement(pid);
        false

      # tx data cached but not registered and not already dropped
      [{_txid, nil, status}] when status != nil ->
        case :ets.lookup(:sync_cache, txid) do
          [] -> true;

          _ -> decrement(pid);
        end
        :ets.delete(:mempool_cache, txid);
        get(pid)

      # tx fully processed and not already dropped
      [{txid, data, _status}] when data != nil ->
        :ets.delete(:mempool_cache, txid);
        {inputs, _value, _inflated} = data;
        uncache_spends(inputs);
        decrement(pid);
        get(pid)

      _ -> false
    end
  end

  defp send_mempool_count(pid) do
    count = get(pid)
    case Jason.encode(%{type: "count", count: count}) do
      {:ok, payload} ->
        Registry.dispatch(Registry.BitcoinStream, "txs", fn(entries) ->
          for {pid, _} <- entries do
            Process.send(pid, payload, []);
          end
        end)
      {:error, reason} -> Logger.error("Error json encoding count: #{reason}");
    end
  end

  defp sync_queue(_pid, []) do
    true
  end

  defp sync_queue(pid, [{txid, sequence} | tail]) do
    register(pid, txid, sequence, true);
    sync_queue(pid, tail)
  end

  def sync(pid) do
    Logger.info("Preparing mempool sync");
    with  {:ok, 200, %{"mempool_sequence" => sequence, "txids" => txns}} <- RPC.request(:rpc, "getrawmempool", [false, true]) do
      set_seq(pid, sequence);
      count = length(txns);
      set(pid, count);
      cache_sync_ids(pid, txns);

      # handle queue accumulated while loading the mempool
      queue = get_queue(pid);
      sync_queue(pid, queue);
      set_queue(pid, []);

      Logger.info("Loaded #{count} mempool transactions");
      send_mempool_count(pid);
      do_sync(pid, txns);
      :ok
    else
      err ->
        Logger.error("Pool sync failed");
        Logger.error("#{inspect(err)}");
        #retry after 30 seconds
        :timer.sleep(10000);
        sync(pid)
    end
  end

  def do_sync(pid, txns) do
    Logger.info("Syncing #{length(txns)} mempool transactions");
    sync_mempool(pid, txns);
    Logger.info("MEMPOOL SYNC FINISHED");
    set_done(pid);
    :ok
  end

  defp sync_mempool(pid, txns) do
    sync_mempool_txns(pid, txns)
  end
  #
  # defp sync_mempool_txn(pid, txid) do
  #   case :ets.lookup(:mempool_cache, txid) do
  #     [] ->
  #       with  {:ok, 200, hextx} <- RPC.request(:rpc, "getrawtransaction", [txid]),
  #             rawtx <- Base.decode16!(hextx, case: :lower),
  #             {:ok, txn } <- BitcoinTx.decode(rawtx) do
  #         register(pid, txid, nil, false);
  #         insert(pid, txid, txn)
  #       else
  #         _ -> Logger.debug("sync_mempool_txn failed #{txid}")
  #       end
  #
  #     [_] -> true
  #   end
  # end
  #
  # defp sync_mempool_txns(_, [], count) do
  #   count
  # end
  #
  # defp sync_mempool_txns(pid, [head | tail], count) do
  #   Logger.debug("Syncing mempool tx #{count}/#{count + length(tail) + 1} | #{head}");
  #   sync_mempool_txn(pid, head);
  #   sync_mempool_txns(pid, tail, count + 1)
  # end


  defp sync_batch(pid, batch) do
    with  batch_params <- Enum.map(batch, fn txid -> [[txid], txid] end),
          {:ok, 200, txs} <- RPC.batch_request(:rpc, "getrawtransaction", batch_params, true),
          failures <- Enum.filter(txs, fn %{"error" => error} -> error != nil end),
          successes <- Enum.filter(txs, fn %{"error" => error} -> error == nil end) do
        Enum.each(successes, fn tx ->
          with  %{"error" => nil, "id" => _txid, "result" => hextx} <- tx,
                rawtx <- Base.decode16!(hextx, case: :lower),
                {:ok, txn } <- BitcoinTx.decode(rawtx) do
            register(pid, txn.id, nil, false);
            insert(pid, txn.id, txn)
          end
        end);
        case length(failures) do
          count when count > 0 ->
            Logger.info("Failed to sync #{length(failures)} transactions")

          _ -> false
        end
        {:ok, length(successes)}
    else
      _ ->
        :error
    end

  catch
    err ->
      Logger.error("unexpected error syncing batch");
      IO.inspect(err);
      :error
  end

  defp sync_mempool_txns(_pid, [], count) do
    {:ok, count}
  end

  defp sync_mempool_txns(pid, [next_chunk | rest], count) do
    :timer.sleep(250);
    case sync_batch(pid, next_chunk) do
      {:ok, batch_count} ->
        Logger.info("synced #{batch_count + count} mempool transactions");
        sync_mempool_txns(pid, rest, batch_count + count)

      _ ->
        Logger.info("Failed to sync #{length(next_chunk)} mempool transactions");
        sync_mempool_txns(pid, rest, count)
    end
  end

  def sync_mempool_txns(pid, txns) do
    sync_mempool_txns(pid, Enum.chunk_every(txns, 50), 0)
  end


  defp cache_sync_ids(pid, txns) do
    :ets.delete_all_objects(:sync_cache);
    cache_sync_ids(pid, txns, 0)
  end

  defp cache_sync_ids(pid, [head | tail], cached) do
    :ets.insert(:sync_cache, {head, true});
    cache_sync_ids(pid, tail, cached + 1)
  end

  defp cache_sync_ids(_pid, [], cached) do
    cached
  end

  def clear_block_txs(pid, block) do
    :ets.delete_all_objects(:block_cache)
    clear_block_txs(pid, block.txns, 0)
  end

  # clear confirmed transactions
  # return the total number removed from the mempool
  # i.e. the amount by which to decrement the mempool counter
  defp clear_block_txs(pid, [], _cleared) do
    get(pid)
  end

  defp clear_block_txs(pid, [head | tail], cleared) do
    :ets.insert(:block_cache, {head.id, true})
    if drop(pid, head.id) do # tx was in the mempool
      clear_block_txs(pid, tail, cleared + 1)
    else
      case :ets.lookup(:sync_cache, head.id) do
        # tx was not in the mempool nor queued for processing
        [] -> clear_block_txs(pid, tail, cleared)

        # tx was not in the mempool, but is queued for processing
        _ -> clear_block_txs(pid, tail, cleared + 1)
      end
    end
  end

  defp cache_spend(txid, index, input) do
    :ets.insert(:spend_cache, {[input.prev_txid, input.prev_vout], [txid, index]})
  end
  defp cache_spends(_txid, _index, []) do
    :ok
  end
  defp cache_spends(txid, index, [input | rest]) do
    cache_spend(txid, index, input);
    cache_spends(txid, index + 1, rest)
  end
  defp cache_spends(txid, inputs) do
    cache_spends(txid, 0, inputs)
  end

  defp uncache_spend(input) do
    :ets.delete(:spend_cache, [input.prev_txid, input.prev_vout])
  end
  defp uncache_spends([]) do
    :ok
  end
  defp uncache_spends([input | rest]) do
    uncache_spend(input);
    uncache_spends(rest)
  end
  defp uncache_spends(inputs) do
    uncache_spends(inputs)
  end
end
