# Ruby bindings for lzws library.
# Copyright (c) 2019 AUTHORS, MIT License.

require_relative "abstract"
require_relative "../common"
require_relative "../minitest"
require_relative "../option"

require "lzws/stream/writer"
require "lzws/string"
require "socket"

module LZWS
  module Test
    module Stream
      class Writer < Abstract
        Target = LZWS::Stream::Writer
        String = LZWS::String

        ARCHIVE_PATH     = Common::ARCHIVE_PATH
        UNIX_SOCKET_PATH = Common::UNIX_SOCKET_PATH
        ENCODINGS        = Common::ENCODINGS
        TEXTS            = Common::TEXTS
        PORTION_LENGTHS  = Common::PORTION_LENGTHS

        COMPATIBLE_OPTION_COMBINATIONS = Option::COMPATIBLE_OPTION_COMBINATIONS

        def test_invalid_initialize
          Option::INVALID_COMPRESSOR_OPTIONS.each do |invalid_options|
            assert_raises ValidateError do
              target.new ::STDOUT, invalid_options
            end
          end

          super
        end

        def test_encoding
          TEXTS.each do |text|
            ENCODINGS.each do |external_encoding|
              target_text = text.encode(
                external_encoding,
                :invalid => :replace,
                :undef   => :replace,
                :replace => "?"
              )

              COMPATIBLE_OPTION_COMBINATIONS.each do |compressor_options, decompressor_options|
                ::File.open ARCHIVE_PATH, "wb" do |file|
                  instance = target.new file, compressor_options, :external_encoding => text.encoding
                  assert instance.external_encoding, text.encoding

                  instance.set_encoding(
                    external_encoding,
                    nil,
                    :invalid => :replace,
                    :undef   => :replace,
                    :replace => "?"
                  )
                  assert instance.external_encoding, external_encoding

                  begin
                    instance.write text
                  ensure
                    instance.close
                  end
                end

                compressed_text = ::File.read ARCHIVE_PATH
                check_text target_text, compressed_text, decompressor_options
              end
            end
          end
        end

        # -- synchronous --

        def test_texts
          TEXTS.each do |text|
            PORTION_LENGTHS.each do |portion_length|
              sources = get_sources text, portion_length

              COMPATIBLE_OPTION_COMBINATIONS.each do |compressor_options, decompressor_options|
                ::File.open ARCHIVE_PATH, "wb" do |file|
                  instance = target.new file, compressor_options

                  begin
                    instance.write(*sources)
                    instance.flush
                    assert instance.pos, text.bytesize
                  ensure
                    refute instance.closed?
                    instance.close
                    assert instance.closed?
                  end
                end

                compressed_text = ::File.read ARCHIVE_PATH
                check_text text, compressed_text, decompressor_options
              end
            end
          end
        end

        def test_rewind
          COMPATIBLE_OPTION_COMBINATIONS.each do |compressor_options, decompressor_options|
            compressed_texts = []

            ::File.open ARCHIVE_PATH, "wb" do |file|
              instance = target.new file, compressor_options

              begin
                TEXTS.each do |text|
                  instance.write text
                  instance.flush
                  assert instance.pos, text.bytesize

                  compressed_texts << ::File.read(ARCHIVE_PATH)

                  instance.rewind
                  assert instance.pos, 0

                  file.truncate 0
                end
              ensure
                instance.close
              end
            end

            TEXTS.each.with_index do |text, index|
              compressed_text = compressed_texts[index]
              check_text text, compressed_text, decompressor_options
            end
          end
        end

        # -- asynchronous --

        def test_texts_nonblock
          TEXTS.each do |text|
            PORTION_LENGTHS.each do |portion_length|
              sources = get_sources text, portion_length

              COMPATIBLE_OPTION_COMBINATIONS.each do |compressor_options, decompressor_options|
                compressed_text = "".b

                ::File.delete UNIX_SOCKET_PATH if ::File.exist? UNIX_SOCKET_PATH
                server = ::UNIXServer.new UNIX_SOCKET_PATH

                # Real unix server will be better for testing nonblock methods.
                server_thread = ::Thread.new do
                  socket = server.accept

                  # Read nonblock limited by portion length will provide a great amount of wait writable errors on client.
                  begin
                    loop do
                      compressed_text += socket.read_nonblock portion_length
                    rescue ::IO::WaitReadable
                      ::IO.select [socket]
                    rescue ::EOFError
                      break
                    end
                  ensure
                    socket.close
                  end
                end

                socket   = ::UNIXSocket.new UNIX_SOCKET_PATH
                instance = target.new socket, compressor_options

                begin
                  sources.each do |source|
                    loop do
                      begin
                        bytes_written = instance.write_nonblock source
                      rescue ::IO::WaitWritable
                        ::IO.select nil, [socket]
                        retry
                      end

                      source = source.byteslice bytes_written, source.bytesize - bytes_written
                      break if source.bytesize == 0
                    end
                  end

                  loop do
                    begin
                      is_flushed = instance.flush_nonblock
                    rescue ::IO::WaitWritable
                      ::IO.select nil, [socket]
                      retry
                    end

                    break if is_flushed
                  end

                  assert instance.pos, text.bytesize

                ensure
                  refute instance.closed?

                  loop do
                    begin
                      is_closed = instance.close_nonblock
                    rescue ::IO::WaitWritable
                      ::IO.select nil, [socket]
                      retry
                    end

                    break if is_closed
                  end

                  assert instance.closed?
                end

                server_thread.join

                check_text text, compressed_text, decompressor_options
              end
            end
          end
        end

        def test_rewind_nonblock
          COMPATIBLE_OPTION_COMBINATIONS.each do |compressor_options, decompressor_options|
            compressed_texts = []

            ::File.open ARCHIVE_PATH, "wb" do |file|
              instance = target.new file, compressor_options

              begin
                TEXTS.each do |text|
                  instance.write text
                  instance.flush
                  assert instance.pos, text.bytesize

                  compressed_texts << ::File.read(ARCHIVE_PATH)

                  loop do
                    begin
                      is_rewinded = instance.rewind_nonblock
                    rescue ::IO::WaitWritable
                      ::IO.select nil, [socket]
                      retry
                    end

                    break if is_rewinded
                  end

                  assert instance.pos, 0

                  file.truncate 0
                end
              ensure
                instance.close
              end
            end

            TEXTS.each.with_index do |text, index|
              compressed_text = compressed_texts[index]
              check_text text, compressed_text, decompressor_options
            end
          end
        end

        # -----

        protected def get_sources(text, portion_length)
          sources = text
            .chars
            .each_slice(portion_length)
            .map(&:join)

          return [""] if sources.empty?

          sources
        end

        protected def check_text(text, compressed_text, decompressor_options)
          decompressed_text = String.decompress compressed_text, decompressor_options
          decompressed_text.force_encoding text.encoding

          assert_equal text, decompressed_text
        end
      end

      Minitest << Writer
    end
  end
end
