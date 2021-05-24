# frozen_string_literal: true

require 'rubygems/package'
require 'yaml'
require 'zlib'

module UnityPackage
  # Used to create, modify, or read a .unitypackage file.
  class UnityPackage
    include Enumerable

    Entry = Struct.new(:pathname, :meta, :asset)

    attr_reader :missing_meta_error

    def initialize(unitypackage = nil, missing_meta_error: true)
      @missing_meta_error = missing_meta_error
      @entries = {}

      File.open(unitypackage, 'rb') do |file|
        load(file)
      end if unitypackage
    end

    def each(&block)
      return to_enum(:each) unless block_given?

      @entries.each do |guid, entry|
        yield(guid, entry)
      end
    end

    def <<(files)
      files = [files] unless files.is_a? Array
      files.each do |file|
        next if File.extname(file) == '.meta'
        file_meta = "#{file}.meta"

        unless File.file?(file_meta)
          if missing_meta_error
            raise IOError.new("no meta file for #{file}")
          else
            puts "no meta file for #{file}"
          end
        else
          meta_contents = File.read(file_meta)
          meta = YAML.safe_load(meta_contents)
          entry = Entry.new
          entry.pathname = file
          entry.meta = meta_contents
          entry.asset = File.read(file) if File.file?(file)
          @entries[meta.guid] = entry
        end
      end
    end

    def write(io)
      Zlib::GzipWriter.wrap(io) do |gz|
        Gem::Package::TarWriter.new(gz) do |tar|
          @entries.sort_by { |k| k }.each do |guid, entry|
            # ./guid/asset.meta
            meta_txt = YAML.dump(entry.meta)
            tar.add_file_simple("./#{guid}/asset.meta", 0444, meta_txt.length) do |io|
              io.write(meta_txt)
            end

            # ./guid/pathname
            tar.add_file_simple("./#{guid}/pathname", 0444, entry.pathname.length) do |io|
              io.write(entry.pathname)
            end

            # ./guid/asset
            tar.add_file_simple("./#{guid}/asset", 0444, entry.asset.length) do |io|
              io.write(entry.asset)
            end if entry.asset
          end
        end
      end
    end

    private

    def load(io)
      Zlib::GzipReader.wrap(io) do |gz|
        Gem::Package::TarReader.new(gz) do |tar|
          tar.each do |entry|
            guid = entry.full_name.split('/')[-2]
            next unless guid

            file_name = File.basename(entry.full_name).split('.').last

            @entries[guid] ||= Entry.new
            # @entries[guid].instance_variable_set("@#{file_name}", entry.read)

            case file_name
            when 'pathname'
              @entries[guid].pathname = entry.read
            when 'asset'
              @entries[guid].asset = entry.read
            when 'meta'
              @entries[guid].meta = YAML.safe_load(entry.read)
            end
          end
        end
      end
    end
  end
end
