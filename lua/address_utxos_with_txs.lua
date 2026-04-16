-- Batch fetch UTXOs for an address with full transaction details
-- This replaces multiple individual esplora_tx calls with a single script execution
-- Args: address

local address = args[1]

-- Fetch all UTXOs for the address
local utxos = _RPC.esplora_addressutxo(address)
if not utxos then
    return { 
        utxos = {},
        error = "Failed to fetch UTXOs for address"
    }
end

-- Result table
local result = {
    utxos = {},
    count = 0
}

-- Collect UTXO data (txid, vout, value, status with block_height).
-- Coinbase detection is handled by the Rust parser: UTXOs with <100
-- confirmations and no tx data are conservatively flagged as potentially-coinbase.
for i, utxo in ipairs(utxos) do
    table.insert(result.utxos, {
        txid = utxo.txid,
        vout = utxo.vout,
        value = utxo.value,
        status = utxo.status
    })
    result.count = result.count + 1
end

return result
