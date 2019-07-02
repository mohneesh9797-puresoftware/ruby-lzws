# Ruby bindings for lzws library.
# Copyright (c) 2019 AUTHORS, MIT License.

require "lzws/stream/compressor"
require "lzws/string"

require_relative "../common"
require_relative "../minitest"
require_relative "../option"
require_relative "../validation"

module LZWS
  module Test
    module Stream
      class Compressor < Minitest::Unit::TestCase
        Target = LZWS::Stream::Compressor
        String = LZWS::String

        NOOP_PROC = Validation::NOOP_PROC

        def test_invalid_initialize
          Validation::INVALID_PROCS.each do |invalid_proc|
            assert_raises ValidateError do
              Target.new invalid_proc, NOOP_PROC
            end

            assert_raises ValidateError do
              Target.new NOOP_PROC, invalid_proc
            end
          end

          Option::INVALID_COMPRESSOR_OPTIONS.each do |invalid_options|
            assert_raises ValidateError do
              Target.new NOOP_PROC, NOOP_PROC, invalid_options
            end
          end
        end

        def test_texts
          Common::TEXTS.each do |text|
            Option::COMPATIBLE_OPTION_COMBINATIONS.each do |compressor_options, decompressor_options|
              Common::TEXT_PORTION_LENGTHS.each do |text_portion_length|
                portion_offset = 0

                reader = proc do
                  next nil if !portion_offset == 0 && portion_offset >= text.length

                  next_portion_offset = portion_offset + text_portion_length
                  portion             = text[portion_offset...next_portion_offset]
                  portion_offset      = next_portion_offset

                  portion
                end

                compressed_buffer = StringIO.new
                compressed_buffer.set_encoding Encoding::BINARY

                writer = proc { |portion| compressed_buffer << portion }

                compressor = Target.new reader, writer, compressor_options
                compressor.write_magic_header unless compressor_options[:without_magic_header]
                compressor.write

                compressed_text   = compressed_buffer.string
                decompressed_text = String.decompress compressed_text, decompressor_options

                assert_equal text, decompressed_text
              end
            end
          end
        end
      end

      Minitest << Compressor
    end
  end
end
