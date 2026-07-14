# File: R/helpers_request.R
# DefiLlama-specific request machinery layered on connectcore's transport base. The
# generic funnel (sync/async branch, retry, throttle) lives in connectcore; this
# file keeps only what is DefiLlama-specific: the response envelope. DefiLlama is
# keyless, so there is no `.sign()` seam -- the base leaves connectcore's no-auth
# default in place.

#' Parse and validate a DefiLlama API response (the `.parse_envelope()` seam)
#'
#' The DefiLlama implementation of connectcore's `.parse_envelope(resp)` seam. It
#' handles the three response surfaces the DefiLlama public API presents:
#' 1. **Non-2xx status** (e.g. the HTTP 400 `Protocol not found` a bad protocol slug
#'    returns, the HTTP 404 an unknown path returns, or the HTTP 500 an unknown chain
#'    returns): raised as `defillama_api_error_<status>` with the body as
#'    `body_snippet`.
#' 2. **Empty body** (a 2xx with no content -- e.g. an unknown stablecoin id, which
#'    DefiLlama answers with an empty 200): returns `NULL`, which each parser turns
#'    into its typed zero-row `data.table`.
#' 3. **Success**: the parsed JSON (an object for the list/overview endpoints, a bare
#'    array for the chart endpoints), returned as a nested list
#'    (`simplifyVector = FALSE`).
#'
#' @param resp (class<httr2_response>) the response to parse.
#' @return (list | NULL) the parsed JSON body, or `NULL` for an empty body.
#' @importFrom httr2 resp_status resp_body_string
#' @keywords internal
#' @noRd
parse_defillama_response <- function(resp) {
  assert_args_parse_defillama_response(resp)
  status <- httr2::resp_status(resp)
  final_url <- resp$url
  body_text <- tryCatch(httr2::resp_body_string(resp), error = function(e) "")

  result <- NULL
  if (status < 200L || status >= 300L) {
    abort_defillama_error(
      status = status,
      url = final_url,
      body = body_text,
      message = paste0("DefiLlama HTTP error ", status, "\n", body_text)
    )
  } else if (nzchar(trimws(body_text))) {
    result <- tryCatch(
      jsonlite::fromJSON(body_text, simplifyVector = FALSE),
      error = function(e) {
        abort_defillama_error(
          status = status,
          url = final_url,
          body = body_text,
          message = paste0("DefiLlama returned a non-JSON body on HTTP ", status, ".")
        )
      }
    )
  }
  return(result)
}

#' Reject an unknown dimension-adapter `data_type` before spending a request
#'
#' Validates a `data_type` argument against a venue vocabulary ([DEX_DATA_TYPES] /
#' [FEES_DATA_TYPES]), aborting with a typed [defillama_conditions] validation error
#' naming the valid values. Called by the DEX-volume and fees clients before the call.
#'
#' @param data_type (scalar<character>) the requested dataType (a venue wire value).
#' @param valid (character) the accepted wire values.
#' @return (scalar<character>) `data_type`, invisibly, when valid.
#' @keywords internal
#' @noassert
#' @noRd
defillama_check_data_type <- function(data_type, valid) {
  if (!data_type %in% valid) {
    abort_defillama_validation_error(paste0(
      "Invalid data_type '",
      data_type,
      "'. Valid values: ",
      paste(valid, collapse = ", "),
      "."
    ))
  }
  return(invisible(data_type))
}
