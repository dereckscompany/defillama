# defillama 0.1.2

**Tidied the package's prose: dropped the visible "plain English" labels and fixed a few American spellings, no behaviour change.**

The README and changelog used to flag their plain-language sentences with a bold "In plain terms:" or "In plain English:" tag. Those tags are gone now; the plain-language sentence itself stays exactly where it was, it just no longer wears a label. Three American spellings ("decentralized") were also corrected to the house British spelling ("decentralised") so the package reads consistently throughout.

- Removed 3 scaffolding labels ("In plain terms:" in README.Rmd, "In plain English:" x2 in NEWS.md) while keeping the sentences that followed them.
- Corrected 3 instances of "decentralized" to "decentralised" (README.Rmd, NEWS.md, and the `DefiLlamaVolumes` roxygen title), regenerating `man/DefiLlamaVolumes.Rd` and `README.md` to match.
- Files touched: `README.Rmd`, `NEWS.md`, `R/DefiLlamaVolumes.R`, `man/DefiLlamaVolumes.Rd`, `README.md`.
- No code, argument, column, or API field names were touched; the full test suite (217 fixture tests, 8 live tests skipped offline) and lintr still pass clean.

# defillama 0.1.1

Fix the rendered README: a cross-reference to the promises package was showing up as literal escaped brackets instead of a link.

The README described asynchronous calls using an R help-page cross-reference syntax that only resolves inside R's own help viewer. GitHub does not understand that syntax, so the rendered README on GitHub showed the literal text "[promise][promises::promise]" instead of a working link. This release replaces it with a plain markdown link, matching the fix already shipped in the hyperliquid and polymarket connectors.

- README.Rmd: replaced the Rd-style `[promise][promises::promise]` cross-reference with a plain markdown link to https://rstudio.github.io/promises/, and re-rendered README.md via `scripts/BUILD.sh readme`.

# defillama 0.1.0

Initial release: DefiLlama's public crypto data in the fleet's connector idiom — the third owner-commissioned alt-data wrapper, keyless throughout.

This package fetches the open, no-key DefiLlama API — how much value is locked in every DeFi protocol and chain, how much every stablecoin has in circulation, how much decentralised exchanges trade, and how much fees and revenue protocols earn — through one typed, tested interface that works both synchronously and asynchronously, so our research and the regime layer can consume DeFi data exactly the way they consume exchange data.

- `DefiLlamaStablecoins`: the stablecoins domain (stablecoins.llama.fi) — `get_stablecoins()` (the cross-section with current circulating supply and price), `get_stablecoin_charts()` (the full daily circulating-supply history of one stablecoin or the aggregate — the endpoint the data-scraper's stablecoin-supply collector will migrate onto), and `get_stablecoin_chains()` (current market cap per chain). Sync + async.
- `DefiLlamaProtocols`: protocol and chain TVL (api.llama.fi) — `get_protocols()`, `get_protocol()` (one protocol's historical TVL), `get_chains()` (current per-chain TVL), and `get_historical_chain_tvl()` (a chain's or the whole DeFi aggregate's historical TVL).
- `DefiLlamaVolumes` and `DefiLlamaFees`: the dimension adapters — `get_dexs_overview()` / `get_fees_overview()` (the per-protocol breakdown) and `get_dexs_chart()` / `get_fees_chart()` (the aggregate daily series), with a `data_type` selector (`DEX_DATA_TYPES` / `FEES_DATA_TYPES`) that the returned `data_type` column records so every table stays self-describing.
- Faithful peg-nested unwrapping: DefiLlama nests each stablecoin amount under its peg-type key (`{"peggedUSD": ...}`); the wrapper unwraps the value and keeps the peg type. Measurement columns are typed `numeric | NA` because DefiLlama omits fields freely — an absent measure is `NA`, never `0`, so a genuine zero and a missing value stay distinguishable (grounded to the live behaviour where `totalMintedUSD` carries a value on only ~1 of ~3,150 daily records).
- Typed conditions from birth: `defillama_api_error` layered in front of the `connectcore` transport chain (`defillama_api_error_<status>` → `connectcore_api_error` → `connectcore_error`), and `defillama_validation_error` → `defillama_error` (the domain root), so a caller branches on error type and reads structured fields.
- Built on the shared `connectcore` (>= 0.5.0) transport base — one sync/async funnel threaded from the constructor via `private$.is_async`, GET-idempotent retries, keyless throughout. Grounded against the live keyless API (40 live assertions) and fully-synthetic fixtures offline (217 tests).

Not built in this release (designed and deferred): the single-protocol dimension summaries (`/summary/dexs/{protocol}`, `/summary/fees/{protocol}`), stablecoin price history (`/stablecoinprices`), and instance-free multi-range backfill helpers.
