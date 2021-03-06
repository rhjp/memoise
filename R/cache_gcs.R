#' Google Cloud Storage Cache
#' Google Cloud Storage backed cache, for remote caching.
#'
#' @examples
#'
#' \dontrun{
#' library(googleCloudStorageR)
#' # Set GCS credentials.
#' Sys.setenv("GCS_AUTH_FILE"="<google-service-json>",
#'            "GCS_DEFAULT_BUCKET"="unique-bucket-name")
#'
#' gcs <- cache_gcs("unique-bucket-name")
#' mem_runif <- memoise(runif, cache = gcs)
#' }
#'
#'
#' @param cache_name Bucket name for storing cache files.
#' @param compress Argument passed to \code{saveRDS} or \code{qs::qsave}. One of FALSE, "gzip",
#' "bzip2", "xz", "qs_fast" or "qs_balanced". Default: FALSE.
#' @inheritParams cache_memory
#' @export
cache_gcs <- function(cache_name = googleCloudStorageR::gcs_get_global_bucket(),
                      algo = "sha512", compress = FALSE) {

  if (!(requireNamespace("googleCloudStorageR"))) { stop("Package `googleCloudStorageR` must be installed for `cache_gcs()`.") } # nocov
  if(compress %in% c("qs_fast", "qs_balanced")){
    if (!(requireNamespace("qs"))) { stop("Package `qs` must be installed for \"qs_fast\" or \"qs_balanced\" compression options") } #nocov
  }


  path <- tempfile("memoise-")
  dir.create(path)

  cache_reset <- function() {
    keys <- cache_keys()
    lapply(keys, googleCloudStorageR::gcs_delete_object, bucket = cache_name)
  }

  cache_set <- function(key, value) {
    temp_file <- file.path(path, key)
    on.exit(unlink(temp_file))
    cache_set_fs(value, path, key, compress)
    suppressMessages(
      googleCloudStorageR::gcs_upload(temp_file, name = key, bucket = cache_name)
    )

  }

  cache_get <- function(key) {
    temp_file <- file.path(path, key)
    suppressMessages(
      googleCloudStorageR::gcs_get_object(key,
                                          bucket = cache_name,
                                          saveToDisk = temp_file,
                                          overwrite = TRUE)
    )
    cache_get_fs(path, key, compress)
  }

  cache_has_key <- function(key) {
    objs <- suppressMessages(
      googleCloudStorageR::gcs_list_objects(prefix = key, bucket = cache_name)
      )
    is_here <- objs$name == key
    # if not result is logical(0)
    if(identical(is_here, logical(0))){
      is_here <- FALSE
    }

    is_here
  }

  cache_drop_key <- function(key) {
    googleCloudStorageR::gcs_delete_object(key, bucket = cache_name)
  }

  cache_keys <- function() {
    items <- googleCloudStorageR::gcs_list_objects(bucket = cache_name)
    items$name
  }

  list(
    digest = function(...) digest::digest(..., algo = algo),
    reset = cache_reset,
    set = cache_set,
    get = cache_get,
    has_key = cache_has_key,
    drop_key = cache_drop_key,
    keys = cache_keys
  )
}
