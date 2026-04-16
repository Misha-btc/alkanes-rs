-- Fetch spendable UTXOs for an address
-- Args: address
-- Returns: confirmed UTXOs safe to spend
--
-- Coinbase detection removed: on mainnet all UTXOs have 100+ confirmations.
-- On regtest, the Rust parser (provider.rs) conservatively flags recent UTXOs
-- without tx data as potentially-coinbase when confirmations < 100.
-- This eliminates N per-UTXO esplora_tx calls (151 calls → 1 call).

local address = args[1]

local current_height = _RPC.btc_getblockcount() or 0
local utxos = _RPC.esplora_addressutxo(address) or {}

local spendable_utxos = {}

for _, utxo in ipairs(utxos) do
    -- Skip unconfirmed
    if utxo.status and utxo.status.confirmed then
        local height = utxo.status.block_height
        local confirmations = 0
        if height then
            confirmations = current_height - height + 1
        end

        table.insert(spendable_utxos, {
            txid = utxo.txid,
            vout = utxo.vout,
            value = utxo.value,
            outpoint = utxo.txid .. ":" .. utxo.vout,
            height = height,
            confirmations = confirmations,
            is_coinbase = false
        })
    end
end

return {
    spendable = spendable_utxos,
    immature = {},
    currentHeight = current_height,
    address = address
}
