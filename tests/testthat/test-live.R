# Live tests against the real DefiLlama public API (keyless). All gate on
# DEFILLAMA_LIVE_TESTS = "true" so a normal R CMD check never hits the network. These
# ground the shapes against reality -- the field-presence discipline (measurements
# omitted freely, so `| NA`) that no single-sample fixture can prove.

skip_unless_live <- function() {
  if (!identical(Sys.getenv("DEFILLAMA_LIVE_TESTS"), "true")) {
    skip("DEFILLAMA_LIVE_TESTS != 'true'")
  }
  return(invisible(NULL))
}

# ---- Stablecoins ----

test_that("get_stablecoins returns the live cross-section with the | NA discipline", {
  skip_unless_live()
  sc <- DefiLlamaStablecoins$new()
  dt <- sc$get_stablecoins()
  expect_s3_class(dt, "data.table")
  expect_gt(nrow(dt), 100L)
  expect_named(dt, names(empty_dt_pegged_assets()))
  expect_true(any(dt$symbol == "USDT"))
  expect_type(dt$circulating, "double")
  # gecko_id is populated for the majors but omitted for many -> the | NA holds.
  expect_true(any(is.na(dt$gecko_id)))
})

test_that("get_stablecoin_charts reproduces the absent-optional discipline (USDT)", {
  skip_unless_live()
  sc <- DefiLlamaStablecoins$new()
  dt <- sc$get_stablecoin_charts(stablecoin_id = 1)
  expect_gt(nrow(dt), 1000L)
  expect_named(dt, names(empty_dt_stablecoin_charts()))
  expect_s3_class(dt$datetime, "POSIXct")
  expect_true(all(dt$stablecoin_id == "1"))
  # The always-present measure is populated on effectively every day...
  expect_gt(sum(!is.na(dt$total_circulating_usd)), 1000L)
  # ...while the optional measures are ABSENT (NA) on the vast majority (~1/3150
  # carries totalMintedUSD): the single-sample trap the collector documented.
  expect_true(any(is.na(dt$total_minted_usd)))
  expect_gt(mean(is.na(dt$total_minted_usd)), 0.5)
})

test_that("get_stablecoin_charts aggregate omits the id, and get_stablecoin_chains works", {
  skip_unless_live()
  sc <- DefiLlamaStablecoins$new()
  agg <- sc$get_stablecoin_charts()
  expect_gt(nrow(agg), 1000L)
  expect_true(all(is.na(agg$stablecoin_id)))
  chains <- sc$get_stablecoin_chains()
  expect_gt(nrow(chains), 10L)
  expect_named(chains, names(empty_dt_stablecoin_chains()))
})

# ---- Protocols / chains ----

test_that("get_protocols returns the live protocol list with nullable tvl", {
  skip_unless_live()
  tvl <- DefiLlamaProtocols$new()
  dt <- tvl$get_protocols()
  expect_gt(nrow(dt), 1000L)
  expect_named(dt, names(empty_dt_protocols()))
  expect_true(any(is.na(dt$tvl))) # DEX-only protocols carry no TVL
  expect_true(any(is.na(dt$chain))) # multi-chain protocols omit the singular chain
})

test_that("get_protocol returns a protocol's historical TVL", {
  skip_unless_live()
  tvl <- DefiLlamaProtocols$new()
  dt <- tvl$get_protocol("aave")
  expect_gt(nrow(dt), 100L)
  expect_true(all(dt$slug == "aave"))
  expect_s3_class(dt$datetime, "POSIXct")
  expect_true(!is.unsorted(dt$datetime))
})

test_that("get_chains and get_historical_chain_tvl return live TVL", {
  skip_unless_live()
  tvl <- DefiLlamaProtocols$new()
  chains <- tvl$get_chains()
  expect_gt(nrow(chains), 50L)
  expect_true(any(chains$name == "Ethereum"))
  hist <- tvl$get_historical_chain_tvl("Ethereum")
  expect_gt(nrow(hist), 100L)
  expect_true(all(hist$chain == "Ethereum"))
  agg <- tvl$get_historical_chain_tvl()
  expect_true(all(is.na(agg$chain)))
})

# ---- DEX volumes / fees ----

test_that("get_dexs_overview and get_dexs_chart return live volumes", {
  skip_unless_live()
  vol <- DefiLlamaVolumes$new()
  overview <- vol$get_dexs_overview()
  expect_gt(nrow(overview), 100L)
  expect_named(overview, names(empty_dt_dimension_overview()))
  expect_true(all(overview$data_type == "dailyVolume"))
  expect_true(any(is.na(overview$total7d))) # young protocols lack a 7d window
  chart <- vol$get_dexs_chart()
  expect_gt(nrow(chart), 100L)
  expect_s3_class(chart$datetime, "POSIXct")
})

test_that("get_fees_overview honours the data_type selector live", {
  skip_unless_live()
  fees <- DefiLlamaFees$new()
  f <- fees$get_fees_overview()
  expect_gt(nrow(f), 100L)
  expect_true(all(f$data_type == "dailyFees"))
  r <- fees$get_fees_overview(data_type = "dailyRevenue")
  expect_gt(nrow(r), 100L)
  expect_true(all(r$data_type == "dailyRevenue"))
})
