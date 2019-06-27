# Ruby bindings for lzws library.
# Copyright (c) 2019 AUTHORS, MIT License.

require "lzws_ext"

require_relative "error"
require_relative "option"

module LZWS
  module String
    def self.compress(source, options = {})
      validate_arguments source

      options = Option.get_compressor_options options

      LZWS._native_compress_string source, options
    end

    def self.decompress(source, options = {})
      validate_arguments source

      options = Option.get_decompressor_options options

      LZWS._native_decompress_string source, options
    end

    def self.validate_arguments(source)
      raise ValidateError unless source.is_a? ::String
    end
  end
end
