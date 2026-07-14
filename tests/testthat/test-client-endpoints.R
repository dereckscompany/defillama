# End-to-end tests: drive every public surface through the shared mock_router (the
# same synthetic fixtures the README renders against). These cover the wiring around
# the parsers -- endpoint strings, the query, the envelope, each method's .parser
# closure, and the return contract.

box::use(./mock_router[.mock_routes])

test_that("get_stablecoins round-trips into the PeggedAssets shape", {
  connectcore::local_mock_api(.mock_routes)
  sc <- DefiLlamaStablecoins$new()
  dt <- sc$get_stablecoins()
  expect_s3_class(dt, "data.table")
  expect_named(dt, names(empty_dt_pegged_assets()))
  expect_identical(nrow(dt), 2L)
  expect_type(dt$circulating, "double")
  expect_true(any(is.na(dt$price))) # the null-price fixture row
})

test_that("get_stablecoin_charts round-trips into the StablecoinCharts shape", {
  connectcore::local_mock_api(.mock_routes)
  sc <- DefiLlamaStablecoins$new()
  dt <- sc$get_stablecoin_charts(stablecoin_id = 1)
  expect_named(dt, names(empty_dt_stablecoin_charts()))
  expect_identical(nrow(dt), 2L)
  expect_s3_class(dt$datetime, "POSIXct")
  expect_true(is.na(dt$total_minted_usd[1])) # absent optional -> NA
  expect_equal(dt$total_minted_usd[2], 0) # present zero stays 0
})

test_that("get_stablecoin_charts surfaces an empty body as a typed zero-row table", {
  connectcore::local_mock_api(.mock_routes)
  sc <- DefiLlamaStablecoins$new()
  dt <- sc$get_stablecoin_charts(stablecoin_id = 999999)
  expect_named(dt, names(empty_dt_stablecoin_charts()))
  expect_identical(nrow(dt), 0L)
})

test_that("get_stablecoin_chains round-trips into the StablecoinChains shape", {
  connectcore::local_mock_api(.mock_routes)
  sc <- DefiLlamaStablecoins$new()
  dt <- sc$get_stablecoin_chains()
  expect_named(dt, names(empty_dt_stablecoin_chains()))
  expect_identical(nrow(dt), 2L)
})

test_that("get_protocols round-trips into the Protocols shape", {
  connectcore::local_mock_api(.mock_routes)
  tvl <- DefiLlamaProtocols$new()
  dt <- tvl$get_protocols()
  expect_named(dt, names(empty_dt_protocols()))
  expect_identical(nrow(dt), 2L)
  expect_type(dt$tvl, "double")
  expect_true(any(is.na(dt$tvl))) # the null-tvl fixture row
})

test_that("get_protocol round-trips one protocol's historical TVL", {
  connectcore::local_mock_api(.mock_routes)
  tvl <- DefiLlamaProtocols$new()
  dt <- tvl$get_protocol("aave")
  expect_named(dt, names(empty_dt_protocol_tvl()))
  expect_identical(nrow(dt), 2L)
  expect_true(all(dt$slug == "aave"))
})

test_that("get_chains round-trips into the ChainTvl shape", {
  connectcore::local_mock_api(.mock_routes)
  tvl <- DefiLlamaProtocols$new()
  dt <- tvl$get_chains()
  expect_named(dt, names(empty_dt_chain_tvl()))
  expect_identical(nrow(dt), 2L)
})

test_that("get_historical_chain_tvl round-trips a chain series", {
  connectcore::local_mock_api(.mock_routes)
  tvl <- DefiLlamaProtocols$new()
  dt <- tvl$get_historical_chain_tvl("Ethereum")
  expect_named(dt, names(empty_dt_chain_tvl_history()))
  expect_identical(nrow(dt), 2L)
  expect_true(all(dt$chain == "Ethereum"))
})

test_that("get_dexs_overview round-trips into the DimensionOverview shape", {
  connectcore::local_mock_api(.mock_routes)
  vol <- DefiLlamaVolumes$new()
  dt <- vol$get_dexs_overview()
  expect_named(dt, names(empty_dt_dimension_overview()))
  expect_identical(nrow(dt), 2L)
  expect_true(all(dt$data_type == "dailyVolume"))
})

test_that("get_dexs_chart round-trips into the DimensionChart shape", {
  connectcore::local_mock_api(.mock_routes)
  vol <- DefiLlamaVolumes$new()
  dt <- vol$get_dexs_chart()
  expect_named(dt, names(empty_dt_dimension_chart()))
  expect_identical(nrow(dt), 2L)
  expect_true(all(dt$data_type == "dailyVolume"))
})

test_that("get_fees_overview round-trips with the fees data_type tag", {
  connectcore::local_mock_api(.mock_routes)
  fees <- DefiLlamaFees$new()
  dt <- fees$get_fees_overview(data_type = "dailyRevenue")
  expect_named(dt, names(empty_dt_dimension_overview()))
  expect_identical(nrow(dt), 2L)
  expect_true(all(dt$data_type == "dailyRevenue"))
})

test_that("get_fees_chart round-trips into the DimensionChart shape", {
  connectcore::local_mock_api(.mock_routes)
  fees <- DefiLlamaFees$new()
  dt <- fees$get_fees_chart()
  expect_named(dt, names(empty_dt_dimension_chart()))
  expect_identical(nrow(dt), 2L)
  expect_true(all(dt$data_type == "dailyFees"))
})

test_that("an unknown data_type aborts with a typed validation error before any call", {
  vol <- DefiLlamaVolumes$new()
  expect_error(vol$get_dexs_overview(data_type = "notreal"), class = "defillama_validation_error")
  fees <- DefiLlamaFees$new()
  expect_error(fees$get_fees_overview(data_type = "notreal"), class = "defillama_validation_error")
})
