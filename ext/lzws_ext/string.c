// Ruby bindings for lzws library.
// Copyright (c) 2019 AUTHORS, MIT License.

#include <lzws/string.h>

#include "lzws_ext/error.h"
#include "lzws_ext/macro.h"
#include "lzws_ext/option.h"
#include "lzws_ext/string.h"
#include "ruby.h"

VALUE lzws_ext_compress_string(VALUE LZWS_EXT_UNUSED(self), VALUE source, VALUE options)
{
  Check_Type(source, T_STRING);

  const char* source_data   = RSTRING_PTR(source);
  size_t      source_length = RSTRING_LEN(source);

  LZWS_EXT_GET_COMPRESSOR_OPTIONS(options);

  // -----

  char*  destination;
  size_t destination_length;

  lzws_result_t result = lzws_compress_string(
    (uint8_t*)source_data, source_length,
    (uint8_t**)&destination, &destination_length, 0,
    max_code_bit_length, block_mode, msb, unaligned_bit_groups, quiet);

  if (result == LZWS_STRING_ALLOCATE_FAILED) {
    lzws_ext_raise_error("AllocateError", "allocate error");
  }
  else if (result == LZWS_STRING_VALIDATE_FAILED) {
    lzws_ext_raise_error("ValidateError", "validate error");
  }
  else if (result != 0) {
    lzws_ext_raise_error("UnexpectedError", "unexpected error");
  }

  // -----

  // Ruby copies string on initialization.
  VALUE result_string = rb_str_new(destination, destination_length);
  free(destination);
  return result_string;
}

VALUE lzws_ext_decompress_string(VALUE LZWS_EXT_UNUSED(self), VALUE source, VALUE options)
{
  Check_Type(source, T_STRING);

  const char* source_data   = RSTRING_PTR(source);
  size_t      source_length = RSTRING_LEN(source);

  LZWS_EXT_GET_DECOMPRESSOR_OPTIONS(options);

  // -----

  char*  destination;
  size_t destination_length;

  lzws_result_t result = lzws_decompress_string(
    (uint8_t*)source_data, source_length,
    (uint8_t**)&destination, &destination_length, 0,
    msb, unaligned_bit_groups, quiet);

  if (result == LZWS_STRING_ALLOCATE_FAILED) {
    lzws_ext_raise_error("AllocateError", "allocate error");
  }
  else if (result == LZWS_STRING_VALIDATE_FAILED) {
    lzws_ext_raise_error("ValidateError", "validate error");
  }
  else if (result == LZWS_STRING_DECOMPRESSOR_CORRUPTED_SOURCE) {
    lzws_ext_raise_error("DecompressorCorruptedSourceError", "decompressor received corrupted source");
  }
  else if (result != 0) {
    lzws_ext_raise_error("UnexpectedError", "unexpected error");
  }

  // -----

  // Ruby copies string on initialization.
  VALUE result_string = rb_str_new(destination, destination_length);
  free(destination);
  return result_string;
}