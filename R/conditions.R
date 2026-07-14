# File: R/conditions.R
# The typed condition family for defillama. Two roots, mirroring the fleet split:
#   * defillama_api_error   -> layered IN FRONT of connectcore's transport chain, so
#     a caller can catch defillama_api_error (any DefiLlama HTTP failure),
#     connectcore_api_error (any HTTP failure fleet-wide), or connectcore_error
#     (any transport failure) and read $status / $url / $body_snippet.
#   * defillama_validation_error -> defillama_error, the connector's DOMAIN root,
#     parallel to connectcore_error and never meeting it (a validation failure is
#     not a transport failure) -- the same split census/coinbase/aisstream use.

#' Typed defillama conditions
#'
#' `defillama` raises **classed conditions** so a caller branches on error *type*
#' and reads structured *fields* instead of matching the message text.
#'
#' ### Class taxonomy
#'
#' - **Transport failures** nest specific -> general as
#'   `defillama_api_error_<status>` -> `defillama_api_error` ->
#'   `connectcore_api_error_<status>` -> `connectcore_api_error` ->
#'   `connectcore_error`, carrying the fields `status`, `url`, and `body_snippet`.
#'   Raised for a non-2xx HTTP status (e.g. the HTTP 400 `Protocol not found` a bad
#'   protocol slug returns, or an HTTP 500 an unknown chain returns).
#' - **Validation failures** nest `defillama_validation_error` -> `defillama_error`
#'   (the domain root). Raised for a malformed argument (an unknown `data_type`, a
#'   missing required identifier) before any request is made.
#'
#' DefiLlama is a keyless public API, so there is no credential-redaction concern in
#' practice, but the `url` is still stored via [connectcore::scrub_url()] for fleet
#' uniformity.
#'
#' @seealso [connectcore::connectcore_conditions]
#' @name defillama_conditions
NULL

#' Raise a typed DefiLlama HTTP API error
#'
#' Signals a condition classed
#' `c("defillama_api_error_<status>", "defillama_api_error",`
#' `"connectcore_api_error_<status>", "connectcore_api_error", "connectcore_error")`
#' carrying the HTTP `status`, the request `url` (query-string credentials redacted
#' with [connectcore::scrub_url()]), and a truncated `body_snippet`. See
#' [defillama_conditions] for the taxonomy.
#'
#' @param status (scalar<count>) the HTTP status code. Also names the most specific
#'   classes.
#' @param url (scalar<character> | NULL) the request URL; credentials are redacted
#'   before storing. Default `NULL`.
#' @param body (scalar<character> | NULL) the response body text; stored truncated
#'   on the `body_snippet` field (named `body_snippet`, not `body`, because
#'   `rlang::abort()` reserves `body`). Default `NULL`.
#' @param message (scalar<character>) the condition message.
#' @return (class<connectcore_error>) never returns normally; signals the classed
#'   condition described above.
#' @importFrom rlang abort caller_env
#' @keywords internal
#' @noassert
#' @noRd
abort_defillama_error <- function(status, url = NULL, body = NULL, message) {
  return(rlang::abort(
    message = message,
    class = c(
      sprintf("defillama_api_error_%d", as.integer(status)),
      "defillama_api_error",
      sprintf("connectcore_api_error_%d", as.integer(status)),
      "connectcore_api_error",
      "connectcore_error"
    ),
    status = as.integer(status),
    url = connectcore::scrub_url(url),
    body_snippet = body,
    call = rlang::caller_env()
  ))
}

#' Raise a typed DefiLlama input-validation error
#'
#' Signals a condition classed `c("defillama_validation_error", "defillama_error")`
#' for a NON-transport failure: an argument is malformed or violates a rule before
#' any request is made. `defillama_error` is the connector's DOMAIN root, parallel to
#' the transport `connectcore_error` root; the two never meet. See
#' [defillama_conditions] for the taxonomy.
#'
#' @param message (scalar<character>) the condition message, passed through verbatim
#'   to [rlang::abort()].
#' @param ... structured fields stored on the condition, read with `e[["field"]]`.
#' @param call (environment) the environment blamed in the traceback; defaults to
#'   the caller.
#' @return (class<defillama_error>) never returns normally; signals the classed
#'   condition described above.
#' @importFrom rlang abort caller_env
#' @keywords internal
#' @noassert
#' @noRd
abort_defillama_validation_error <- function(message, ..., call = rlang::caller_env()) {
  return(rlang::abort(
    message = message,
    class = c("defillama_validation_error", "defillama_error"),
    ...,
    call = call
  ))
}
