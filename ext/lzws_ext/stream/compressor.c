// Ruby bindings for lzws library.
// Copyright (c) 2019 AUTHORS, MIT License.

#include <lzws/buffer.h>
#include <lzws/compressor/common.h>
#include <lzws/compressor/header.h>
#include <lzws/compressor/main.h>
#include <lzws/compressor/state.h>

#include "lzws_ext/error.h"
#include "lzws_ext/macro.h"
#include "lzws_ext/option.h"
#include "lzws_ext/stream/compressor.h"
#include "ruby.h"

static void free_compressor(lzws_ext_compressor_t* compressor_ptr)
{
  lzws_compressor_state_t* state_ptr = compressor_ptr->state_ptr;
  if (state_ptr != NULL) {
    lzws_compressor_free_state(state_ptr);
  }

  uint8_t* destination_buffer = compressor_ptr->destination_buffer;
  if (destination_buffer != NULL) {
    free(destination_buffer);
  }

  free(compressor_ptr);
}

VALUE lzws_ext_allocate_compressor(VALUE klass)
{
  lzws_ext_compressor_t* compressor_ptr;

  VALUE self = Data_Make_Struct(klass, lzws_ext_compressor_t, NULL, free_compressor, compressor_ptr);

  compressor_ptr->state_ptr                           = NULL;
  compressor_ptr->destination_buffer                  = NULL;
  compressor_ptr->destination_buffer_length           = 0;
  compressor_ptr->remaining_destination_buffer        = NULL;
  compressor_ptr->remaining_destination_buffer_length = 0;

  return self;
}

VALUE lzws_ext_initialize_compressor(VALUE LZWS_EXT_UNUSED(self), VALUE options)
{
  LZWS_EXT_GET_COMPRESSOR_OPTIONS(options);

  lzws_ext_compressor_t* compressor_ptr;
  Data_Get_Struct(self, lzws_ext_compressor_t, compressor_ptr);

  // -----

  lzws_compressor_state_t* compressor_state_ptr;

  lzws_result_t result = lzws_compressor_get_initial_state(
    &compressor_state_ptr,
    max_code_bit_length, block_mode, msb, unaligned_bit_groups, quiet);

  if (result != 0) {
    lzws_ext_raise_error("CompressorError", "compressor error");
  }

  compressor_ptr->state_ptr = compressor_state_ptr;

  // -----

  uint8_t* destination_buffer;
  size_t   destination_buffer_length = 0;

  result = lzws_create_buffer_for_compressor(&destination_buffer, &destination_buffer_length, quiet);
  if (result != 0) {
    lzws_ext_raise_error("MemoryAllocationError", "memory allocation error");
  }

  compressor_ptr->destination_buffer                  = destination_buffer;
  compressor_ptr->destination_buffer_length           = destination_buffer_length;
  compressor_ptr->remaining_destination_buffer        = destination_buffer;
  compressor_ptr->remaining_destination_buffer_length = destination_buffer_length;

  return Qnil;
}

VALUE lzws_ext_compressor_write_magic_header(VALUE self)
{
  lzws_ext_compressor_t* compressor_ptr;
  Data_Get_Struct(self, lzws_ext_compressor_t, compressor_ptr);

  // -----

  lzws_result_t result = lzws_compressor_write_magic_header(
    &compressor_ptr->remaining_destination_buffer,
    &compressor_ptr->remaining_destination_buffer_length);

  if (result == 0) {
    return Qtrue;
  }
  else if (result == LZWS_COMPRESSOR_NEEDS_MORE_DESTINATION) {
    return Qfalse;
  }
  else {
    lzws_ext_raise_error("UnexpectedError", "unexpected error");
  }
}

VALUE lzws_ext_compressor_write_header(VALUE self)
{
  lzws_ext_compressor_t* compressor_ptr;
  Data_Get_Struct(self, lzws_ext_compressor_t, compressor_ptr);

  // -----

  lzws_result_t result = lzws_compressor_write_header(
    compressor_ptr->state_ptr,
    &compressor_ptr->remaining_destination_buffer,
    &compressor_ptr->remaining_destination_buffer_length);

  if (result == 0) {
    return Qtrue;
  }
  else if (result == LZWS_COMPRESSOR_NEEDS_MORE_DESTINATION) {
    return Qfalse;
  }
  else {
    lzws_ext_raise_error("UnexpectedError", "unexpected error");
  }
}

VALUE lzws_ext_compressor_write(VALUE self, VALUE source)
{
  lzws_ext_compressor_t* compressor_ptr;
  Data_Get_Struct(self, lzws_ext_compressor_t, compressor_ptr);

  Check_Type(source, T_STRING);

  const char* source_data   = RSTRING_PTR(source);
  size_t      source_length = RSTRING_LEN(source);

  uint8_t* remaining_source_data   = (uint8_t*)source_data;
  size_t   remaining_source_length = source_length;

  // -----

  lzws_result_t result = lzws_compress(
    compressor_ptr->state_ptr,
    &remaining_source_data,
    &remaining_source_length,
    &compressor_ptr->remaining_destination_buffer,
    &compressor_ptr->remaining_destination_buffer_length);

  if (result == LZWS_COMPRESSOR_NEEDS_MORE_SOURCE) {
    return INT2NUM(source_length);
  }
  else if (result == LZWS_COMPRESSOR_NEEDS_MORE_DESTINATION) {
    return INT2NUM(source_length - remaining_source_length);
  }
  else {
    lzws_ext_raise_error("UnexpectedError", "unexpected error");
  }
}

VALUE lzws_ext_compressor_read(VALUE self)
{
  lzws_ext_compressor_t* compressor_ptr;
  Data_Get_Struct(self, lzws_ext_compressor_t, compressor_ptr);

  // -----

  uint8_t* destination_buffer                  = compressor_ptr->destination_buffer;
  size_t   destination_buffer_length           = compressor_ptr->destination_buffer_length;
  uint8_t* remaining_destination_buffer        = compressor_ptr->remaining_destination_buffer;
  size_t   remaining_destination_buffer_length = compressor_ptr->remaining_destination_buffer_length;

  const char* result_data   = (const char*)destination_buffer;
  size_t      result_length = destination_buffer_length - remaining_destination_buffer_length;

  VALUE result = rb_str_new(result_data, result_length);

  // Moving remaining data to the top of the destination buffer.
  if (destination_buffer != remaining_destination_buffer) {
    memmove(destination_buffer, remaining_destination_buffer, remaining_destination_buffer_length);

    compressor_ptr->remaining_destination_buffer        = destination_buffer;
    compressor_ptr->remaining_destination_buffer_length = destination_buffer_length;
  }

  return result;
}

VALUE lzws_ext_flush_compressor(VALUE self)
{
  lzws_ext_compressor_t* compressor_ptr;
  Data_Get_Struct(self, lzws_ext_compressor_t, compressor_ptr);

  // -----

  lzws_result_t result = lzws_flush_compressor(
    compressor_ptr->state_ptr,
    &compressor_ptr->remaining_destination_buffer,
    &compressor_ptr->remaining_destination_buffer_length);

  if (result == 0) {
    return Qtrue;
  }
  else if (result == LZWS_COMPRESSOR_NEEDS_MORE_DESTINATION) {
    return Qfalse;
  }
  else {
    lzws_ext_raise_error("UnexpectedError", "unexpected error");
  }
}
