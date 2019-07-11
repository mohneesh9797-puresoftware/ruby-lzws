# Ruby bindings for lzws library.
# Copyright (c) 2019 AUTHORS, MIT License.

require_relative "abstract"
require_relative "raw/decompressor"

module LZWS
  module Stream
    class Reader < Abstract
      def initialize(source_io, options = {}, *args)
        decompressor = Raw::Decompressor.new options

        super decompressor, source_io, *args
      end

      # each_byte
      # eof?
      # read
      # read_nonblock
      # getbyte
      # ungetbyte
    end
  end
end
