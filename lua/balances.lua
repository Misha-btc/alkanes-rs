-- Comprehensive balance information for an address (replacement for sandshrew_balances)
-- Args: address, protocol_tag (optional, default: "1"), options (optional, default: "")
--   options: comma-separated flags, e.g. "ord" to enable ord_outputs lookup
--   By default ord is SKIPPED — it takes 40+ seconds on mainnet (unstable server).
--   Inscription/rune detection handled by wallet APIs (UniSat) or Rebar REST.

local address = args[1]
local protocol_tag = args[2] or "1"
local options = args[3] or ""
local use_ord = string.find(options, "ord") ~= nil

-- Determine which addresses to query
local addresses = {address}
if asset_address then
    table.insert(addresses, asset_address)
end

-- Remove duplicates
local unique_addresses = {}
local seen = {}
for _, addr in ipairs(addresses) do
    if not seen[addr] then
        seen[addr] = true
        table.insert(unique_addresses, addr)
    end
end

-- Get heights
local ord_height = 0
if use_ord then
    ord_height = _RPC.ord_blockheight() or 0
end
local metashrew_height_str = _RPC.metashrew_height() or "0"
local metashrew_height = tonumber(metashrew_height_str) or 0
local max_indexed_height = use_ord and math.max(ord_height, metashrew_height) or metashrew_height

-- Collect results for all addresses
local all_spendable = {}
local all_assets = {}
local all_pending = {}

for _, addr in ipairs(unique_addresses) do
    local utxos = _RPC.esplora_addressutxo(addr) or {}

    -- Get protorunes/alkanes data (fast, reliable)
    local protorunes = _RPC.alkanes_protorunesbyaddress({
        address = addr,
        protocolTag = protocol_tag
    }) or {}

    -- Optionally get ord outputs (inscriptions and runes) — slow on mainnet
    local ord_outputs = {}
    if use_ord then
        ord_outputs = _RPC.ord_outputs(addr) or {}
    end

    -- Build lookup maps
    local runes_map = {}
    if protorunes.outpoints then
        for _, outpoint in ipairs(protorunes.outpoints) do
            if outpoint.outpoint and outpoint.runes then
                local txid = outpoint.outpoint.txid
                local vout = outpoint.outpoint.vout
                local key = txid .. ":" .. vout
                runes_map[key] = outpoint.runes
            end
        end
    end

    local ord_outputs_map = {}
    if use_ord then
        for _, output in ipairs(ord_outputs) do
            if output.outpoint then
                ord_outputs_map[output.outpoint] = {
                    inscriptions = output.inscriptions or {},
                    ord_runes = output.runes or {}
                }
            end
        end
    end

    -- Process each UTXO
    for _, utxo in ipairs(utxos) do
        local txid = utxo.txid
        local vout = utxo.vout
        local value = utxo.value
        local key = txid .. ":" .. vout

        local height = nil
        if utxo.status and utxo.status.block_height then
            height = utxo.status.block_height
        end

        local utxo_entry = {
            outpoint = key,
            value = value
        }

        if height then
            utxo_entry.height = height
        end

        -- Add alkane runes if present
        if runes_map[key] then
            utxo_entry.runes = runes_map[key]
        end

        -- Add inscriptions and ord_runes if ord enabled
        if use_ord and ord_outputs_map[key] then
            if #ord_outputs_map[key].inscriptions > 0 then
                utxo_entry.inscriptions = ord_outputs_map[key].inscriptions
            end
            if next(ord_outputs_map[key].ord_runes) ~= nil then
                utxo_entry.ord_runes = ord_outputs_map[key].ord_runes
            end
        end

        -- Categorize
        local has_assets = (utxo_entry.runes and #utxo_entry.runes > 0) or
                          (utxo_entry.inscriptions and #utxo_entry.inscriptions > 0) or
                          (utxo_entry.ord_runes and next(utxo_entry.ord_runes) ~= nil)

        local is_confirmed = height and height <= max_indexed_height

        if not is_confirmed then
            table.insert(all_pending, utxo_entry)
        elseif has_assets then
            table.insert(all_assets, utxo_entry)
        else
            table.insert(all_spendable, utxo_entry)
        end
    end
end

return {
    spendable = all_spendable,
    assets = all_assets,
    pending = all_pending,
    ordHeight = ord_height,
    metashrewHeight = metashrew_height
}
