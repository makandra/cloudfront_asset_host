module ActionView
  module Helpers
    module AssetTagHelper

    private

      # Override asset_id so it calculates the key by md5 instead of modified-time
      def rails_asset_id_with_cloudfront(source)
        if @@cache_asset_timestamps && (asset_id = @@asset_timestamps_cache[source])
          asset_id
        else
          path = File.join(ASSETS_DIR, source)
          rewrite_path = File.exist?(path) && !CloudfrontAssetHost.disable_cdn_for_source?(source) && CloudfrontAssetHost::Uploader.current_paths.include?(path)
          asset_id = if rewrite_path 
                        CloudfrontAssetHost.key_for_path(path) 

                     elsif File.exists?(path)
                       ("?" + File.mtime(path).to_i.to_s)
                     else
                       ''
                     end

          if @@cache_asset_timestamps
            @@asset_timestamps_cache_guard.synchronize do
              @@asset_timestamps_cache[source] = asset_id
            end
          end

          asset_id
        end
      end

      # Override asset_path so it prepends the asset_id
      def rewrite_asset_path_with_cloudfront(source, path=nil)
        asset_id = rails_asset_id(source)
        if asset_id.blank?
          source
        elsif asset_id.starts_with?('?')
          source + asset_id
        else
          "/#{asset_id}#{source}"
        end
      end

    end
  end
end
