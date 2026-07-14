# Unit tests for the parse layer: peg-nested unwrapping, the absent-vs-present-zero
# `| NA` contract, the chains join, and constant columns. Fixtures are the same
# synthetic JSON the end-to-end and README paths use, loaded parsed.

fx <- connectcore::load_fixtures(test_path("fixtures"), parse = TRUE)

test_that("peg_value unwraps a peg-nested measure and peg_type reads its key", {
  expect_equal(peg_value(list(peggedUSD = 100)), 100)
  expect_equal(peg_type(list(peggedUSD = 100)), "peggedUSD")
  # Absent measure -> NA (never 0), and NA character for the type.
  expect_true(is.na(peg_value(NULL)))
  expect_true(is.na(peg_type(NULL)))
  # A genuine present zero stays 0.
  expect_equal(peg_value(list(peggedUSD = 0)), 0)
})

test_that("join_chains ;-joins a string array and NA for empty", {
  expect_equal(join_chains(list("Ethereum", "Tron")), "Ethereum;Tron")
  expect_true(is.na(join_chains(NULL)))
  expect_true(is.na(join_chains(list())))
})

test_that("parse_pegged_assets extracts identity, price, and peg-nested circulating", {
  dt <- parse_pegged_assets(fx$stablecoins)
  expect_s3_class(dt, "data.table")
  expect_identical(nrow(dt), 2L)
  expect_named(dt, names(empty_dt_pegged_assets()))
  usdt <- dt[symbol == "USDT"]
  expect_equal(usdt$circulating, 100000000000)
  expect_equal(usdt$peg_type, "peggedUSD")
  expect_equal(usdt$chains, "Ethereum;Tron;BSC")
  # DAI: null gecko_id, absent priceSource, null price -> all NA.
  dai <- dt[symbol == "DAI"]
  expect_true(is.na(dai$gecko_id))
  expect_true(is.na(dai$price_source))
  expect_true(is.na(dai$price))
})

test_that("parse_stablecoin_charts keeps absent optionals NA but a present zero 0", {
  dt <- parse_stablecoin_charts(fx$stablecoin_charts, stablecoin_id = 1)
  expect_identical(nrow(dt), 2L)
  expect_s3_class(dt$datetime, "POSIXct")
  expect_equal(as.character(dt$stablecoin_id), c("1", "1"))
  # Day 1: optional measures absent -> NA, never 0.
  expect_true(is.na(dt$total_unreleased[1]))
  expect_true(is.na(dt$total_minted_usd[1]))
  expect_true(is.na(dt$total_bridged_to_usd[1]))
  # Day 2: present, and a genuine 0 stays 0 (distinct from missing).
  expect_equal(dt$total_unreleased[2], 5)
  expect_equal(dt$total_minted_usd[2], 0)
  expect_equal(dt$total_bridged_to_usd[2], 0)
})

test_that("parse_stablecoin_charts records NA stablecoin_id for the aggregate", {
  dt <- parse_stablecoin_charts(fx$stablecoin_charts, stablecoin_id = NULL)
  expect_true(all(is.na(dt$stablecoin_id)))
})

test_that("parse_stablecoin_chains unwraps the peg-nested chain market cap", {
  dt <- parse_stablecoin_chains(fx$stablecoin_chains)
  expect_identical(nrow(dt), 2L)
  expect_equal(dt[name == "Ethereum"]$total_circulating_usd, 80000000000)
  expect_equal(dt[name == "Ethereum"]$peg_type, "peggedUSD")
})

test_that("parse_protocols surfaces an absent chain and null tvl as NA", {
  dt <- parse_protocols(fx$protocols)
  expect_identical(nrow(dt), 2L)
  expect_named(dt, names(empty_dt_protocols()))
  uni <- dt[name == "Uniswap"]
  expect_true(is.na(uni$chain)) # multi-chain: `chain` key absent
  expect_true(is.na(uni$tvl)) # null tvl -> NA, not 0
  expect_true(is.na(uni$cmc_id))
  expect_equal(uni$parent_protocol, "parent#uniswap")
  expect_equal(uni$chains, "Ethereum;Arbitrum;Base")
  aave <- dt[name == "AAVE V3"]
  expect_equal(aave$tvl, 15000000000)
  expect_true(is.na(aave$pool2)) # null pool2
})

test_that("parse_protocol_tvl extracts the tvl series with a constant slug column", {
  dt <- parse_protocol_tvl(fx$protocol_tvl, slug = "aave")
  expect_identical(nrow(dt), 2L)
  expect_true(all(dt$slug == "aave"))
  expect_s3_class(dt$datetime, "POSIXct")
  expect_equal(dt$tvl_usd, c(54026260, 60000000))
})

test_that("parse_chain_tvl surfaces absent chain metadata as NA", {
  dt <- parse_chain_tvl(fx$chains)
  expect_identical(nrow(dt), 2L)
  some <- dt[name == "SomeChain"]
  expect_true(is.na(some$chain_id))
  expect_true(is.na(some$token_symbol))
  expect_true(is.na(some$gecko_id))
  expect_equal(dt[name == "Ethereum"]$chain_id, "1")
})

test_that("parse_chain_tvl_history builds a sorted series with the queried chain", {
  dt <- parse_chain_tvl_history(fx$chain_tvl_history, chain = "Ethereum")
  expect_identical(nrow(dt), 2L)
  expect_true(all(dt$chain == "Ethereum"))
  expect_true(!is.unsorted(dt$datetime))
  # NULL chain -> NA (the all-chains aggregate).
  dt2 <- parse_chain_tvl_history(fx$chain_tvl_history, chain = NULL)
  expect_true(all(is.na(dt2$chain)))
})

test_that("parse_dimension_overview tags data_type and keeps absent totals NA", {
  dt <- parse_dimension_overview(fx$dexs, data_type = "dailyVolume")
  expect_identical(nrow(dt), 2L)
  expect_true(all(dt$data_type == "dailyVolume"))
  newdex <- dt[name == "NewDex"]
  expect_true(is.na(newdex$total24h)) # null total24h
  expect_true(is.na(newdex$total7d)) # absent total7d
  expect_true(is.na(newdex$parent_protocol)) # absent parentProtocol
  expect_equal(newdex$total_all_time, 5000000)
})

test_that("parse_dimension_chart flattens the [ts, value] pairs, sorted, tagged", {
  dt <- parse_dimension_chart(fx$fees, data_type = "dailyFees")
  expect_identical(nrow(dt), 2L)
  expect_true(all(dt$data_type == "dailyFees"))
  expect_s3_class(dt$datetime, "POSIXct")
  expect_equal(dt$value, c(50000, 60000))
  expect_true(!is.unsorted(dt$datetime))
})
