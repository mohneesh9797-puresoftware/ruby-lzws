# Ruby bindings for lzws library.
# Copyright (c) 2019 AUTHORS, MIT License.

require_relative "abstract"
require_relative "../common"
require_relative "../minitest"
require_relative "../option"
require_relative "../validation"

require "lzws/stream/reader"
require "lzws/string"
require "socket"

module LZWS
  module Test
    module Stream
      class Reader < Abstract
        Target = LZWS::Stream::Reader
        String = LZWS::String

        ARCHIVE_PATH     = Common::ARCHIVE_PATH
        PORT             = Common::PORT
        ENCODINGS        = Common::ENCODINGS
        TEXTS            = Common::TEXTS
        PORTION_LENGTHS  = Common::PORTION_LENGTHS

        COMPATIBLE_OPTION_COMBINATIONS = Option::COMPATIBLE_OPTION_COMBINATIONS

        def test_invalid_initialize
          Option::INVALID_DECOMPRESSOR_OPTIONS.each do |invalid_options|
            assert_raises ValidateError do
              target.new ::STDIN, invalid_options
            end
          end

          (Validation::INVALID_POSITIVE_INTEGERS - [nil]).each do |invalid_integer|
            assert_raises ValidateError do
              target.new ::STDIN, :io_portion_bytesize => invalid_integer
            end
          end

          super
        end

        # -- synchronous --

        def test_invalid_read
          instance = target.new ::STDIN

          (Validation::INVALID_NOT_NEGATIVE_INTEGERS - [nil]).each do |invalid_integer|
            assert_raises ValidateError do
              instance.read invalid_integer
            end
          end

          (Validation::INVALID_STRINGS - [nil]).each do |invalid_string|
            assert_raises ValidateError do
              instance.read nil, invalid_string
            end
          end
        end

        def test_read
          TEXTS.each do |text|
            COMPATIBLE_OPTION_COMBINATIONS.each do |compressor_options, decompressor_options|
              [true, false].map do |with_buffer|
                prev_result = "".b

                PORTION_LENGTHS.each do |portion_length|
                  write_archive text, compressor_options

                  decompressed_text = "".b

                  ::File.open ARCHIVE_PATH, "rb" do |file|
                    instance = target.new file, decompressor_options

                    begin
                      result = instance.read(0)
                      assert_equal result, ""

                      loop do
                        result =
                          if with_buffer
                            instance.read portion_length, prev_result
                          else
                            instance.read portion_length
                          end

                        break if result.nil?

                        assert_equal result, prev_result if with_buffer
                        decompressed_text << result
                      end

                      assert instance.pos, decompressed_text.bytesize
                    ensure
                      refute instance.closed?
                      instance.close
                      assert instance.closed?
                    end
                  end

                  decompressed_text.force_encoding text.encoding
                  assert_equal text, decompressed_text
                end

                write_archive text, compressor_options

                decompressed_text = nil

                ::File.open ARCHIVE_PATH, "rb" do |file|
                  instance = target.new file, decompressor_options

                  begin
                    if with_buffer
                      decompressed_text = instance.read nil, prev_result
                      assert_equal decompressed_text, prev_result
                    else
                      decompressed_text = instance.read
                    end

                    assert instance.pos, decompressed_text.bytesize
                  ensure
                    refute instance.closed?
                    instance.close
                    assert instance.closed?
                  end
                end

                decompressed_text.force_encoding text.encoding
                assert_equal text, decompressed_text
              end
            end
          end
        end

        def test_encoding
          TEXTS.each do |text|
            external_encoding = text.encoding

            COMPATIBLE_OPTION_COMBINATIONS.each do |compressor_options, decompressor_options|
              PORTION_LENGTHS.each do |portion_length|
                write_archive text, compressor_options

                decompressed_text = "".b

                ::File.open ARCHIVE_PATH, "rb" do |file|
                  instance = target.new file, decompressor_options

                  begin
                    result = instance.read(0)
                    assert_equal result.encoding, Encoding::BINARY

                    loop do
                      result = instance.read portion_length
                      break if result.nil?

                      assert_equal result.encoding, Encoding::BINARY
                      decompressed_text << result
                    end
                  ensure
                    instance.close
                  end
                end

                decompressed_text.force_encoding external_encoding
                assert_equal text, decompressed_text
              end

              # We don't need to transcode between same encodings.
              (ENCODINGS - [external_encoding]).each do |internal_encoding|
                transcode_options = {
                  :invalid => :replace,
                  :undef   => :replace,
                  :replace => "?"
                }
                target_text = text.encode internal_encoding, transcode_options

                write_archive text, compressor_options

                decompressed_text = nil

                ::File.open ARCHIVE_PATH, "rb" do |file|
                  instance = target.new(
                    file,
                    decompressor_options,
                    :external_encoding => external_encoding,
                    :internal_encoding => internal_encoding
                  )
                  assert instance.external_encoding, external_encoding
                  assert instance.internal_encoding, internal_encoding

                  begin
                    instance.set_encoding(
                      external_encoding,
                      internal_encoding,
                      transcode_options
                    )
                    assert instance.external_encoding, external_encoding
                    assert instance.internal_encoding, internal_encoding

                    decompressed_text = instance.read
                    assert_equal decompressed_text.encoding, internal_encoding
                  ensure
                    instance.close
                  end
                end

                assert_equal target_text, decompressed_text
              end
            end
          end
        end

        # -- asynchronous --

        # -----

        protected def write_archive(text, compressor_options)
          compressed_text = String.compress text, compressor_options
          ::File.write ARCHIVE_PATH, compressed_text
        end
      end

      Minitest << Reader
    end
  end
end
