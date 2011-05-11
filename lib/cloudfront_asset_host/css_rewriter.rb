require 'tempfile'

module CloudfrontAssetHost
  module CssRewriter

    # Location of the stylesheets directory
    mattr_accessor :stylesheets_dir
    self.stylesheets_dir = File.join(Rails.public_path, 'stylesheets')

    class << self
      # matches optional quoted url(<path>)
      ReplaceRexeg = /url\(["']?([^\)\?\#"']+)(\#[^"']*)?(\?[^"']*)?["']?\)/i

      # Returns the path to the temporary file that contains the
      # rewritten stylesheet
      def rewrite_stylesheet(path, ssl = false)
        contents = File.read(path)
        contents.gsub!(ReplaceRexeg) do |match|
          rewrite_asset_link(match, path, ssl)
        end

        tmp = Tempfile.new("cfah-css")
        tmp.write(contents)
        tmp.flush
        tmp
      end

    private

      def rewrite_asset_link(asset_link, stylesheet_path, ssl)
        match = asset_link.match(ReplaceRexeg)
        url = match[1]
        hash = match[2] || ''
        query = match[3] || ''

        if url
          path = path_for_url(url, stylesheet_path)

          if path.present? && (!CloudfrontAssetHost::Uploader.current_paths.include?(path) || CloudfrontAssetHost.disable_cdn_for_source?(path))
            path_relative_to_public_path = path.gsub(Rails.public_path, '')
            "url(#{CloudfrontAssetHost.asset_host(path_relative_to_public_path, nil, nil, ssl)}#{path_relative_to_public_path}#{hash}#{query})"
          elsif path.present? && File.exists?(path)
            key = CloudfrontAssetHost.key_for_path(path) + path.gsub(Rails.public_path, '') + hash
            "url(#{CloudfrontAssetHost.asset_host(url, nil, true, ssl)}/#{key})"
          else
            puts "Could not extract path: #{path}"
            asset_link
          end
        else
          puts "Could not find url in #{asset_link}"
          asset_link
        end
      end

      def path_for_url(url, stylesheet_path)
        if url.start_with?('/')
          # absolute to public path
          File.expand_path(File.join(Rails.public_path, url))
        else
          # relative to stylesheet_path
          File.expand_path(File.join(File.dirname(stylesheet_path), url))
        end
      end

      def stylesheets_to_rewrite
        Dir.glob("#{stylesheets_dir}/**/*.css")
      end

    end

  end
end
