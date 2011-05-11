require 'test_helper'

class CloudfrontAssetHostTest < Test::Unit::TestCase

  context "A configured plugin" do
    setup do
      CloudfrontAssetHost.configure do |config|
        config.cname  = "assethost.com"
        config.bucket = "bucketname"
        config.key_prefix = ""
        config.enabled = false
        config.asset_host_without_cloudfront = 'www.example.com'
      end
    end

    should "add methods to asset-tag-helper" do
      assert ActionView::Helpers::AssetTagHelper.private_method_defined?('rails_asset_id_with_cloudfront')
      assert ActionView::Helpers::AssetTagHelper.private_method_defined?('rewrite_asset_path_with_cloudfront')
    end

    should "not enable itself by default" do
      assert_equal false, CloudfrontAssetHost.enabled
      assert_equal "", ActionController::Base.asset_host
    end

    should "return key for path" do
      assert_equal "8ed41cb87", CloudfrontAssetHost.key_for_path(File.join(RAILS_ROOT, 'public', 'javascripts', 'application.js'))
    end

    should "prepend prefix to key" do
      CloudfrontAssetHost.key_prefix = "prefix/"
      assert_equal "prefix/8ed41cb87", CloudfrontAssetHost.key_for_path(File.join(RAILS_ROOT, 'public', 'javascripts', 'application.js'))
    end

    should "default asset_dirs setting" do
      assert_equal %w(images javascripts stylesheets), CloudfrontAssetHost.asset_dirs
    end

    context "asset-host" do

      setup do
        @source = "/dd34ef/javascripts/application.js"
      end

      should "use cname for asset_host" do
        assert_equal "http://assethost.com", CloudfrontAssetHost.asset_host(@source)
      end

      should "use interpolated cname for asset_host" do
        CloudfrontAssetHost.cname = "assethost-%d.com"
        assert_equal "http://assethost-3.com", CloudfrontAssetHost.asset_host(@source)
      end

      should "call proc for asset_host" do
        CloudfrontAssetHost.cname = Proc.new { |source, request| "http://assethost-proc.com" }
        assert_equal "http://assethost-proc.com", CloudfrontAssetHost.asset_host(@source)
      end

      should "use bucket_host when cname is not present" do
        CloudfrontAssetHost.cname = nil
        assert_equal "http://bucketname.s3.amazonaws.com", CloudfrontAssetHost.asset_host(@source)
      end

      should "add plain_prefix if present" do
        CloudfrontAssetHost.plain_prefix = "prefix"
        assert_equal "http://assethost.com/prefix", CloudfrontAssetHost.asset_host(@source)
      end

      should 'use the HOST constant if the file exists locally' do
        assert_equal 'http://www.example.com', CloudfrontAssetHost.asset_host('images/image.png')
      end

      should 'use https if the request is an https request and the file exists locally' do
        request = stub(:headers => {}, :protocol => 'https://')
        assert_equal 'https://www.example.com', CloudfrontAssetHost.asset_host('images/image.png', request)
      end

      should 'use https if ssl is forced and the file exists locally' do
        assert_equal 'https://www.example.com', CloudfrontAssetHost.asset_host('images/image.png', nil, false, true)
      end

      should "use https if the request is an https request" do
        request = stub(:headers => {}, :protocol => 'https://')
        assert_equal "https://assethost.com", CloudfrontAssetHost.asset_host(@source, request)
      end

      should "use https if ssl is forced" do
        assert_equal "https://assethost.com", CloudfrontAssetHost.asset_host(@source, nil, false, true)
      end

      should "use the ssl_prefix for stylesheets requested over https" do
        CloudfrontAssetHost.ssl_prefix = "ssl_prefix"
        request = stub(:headers => {}, :protocol => 'https://')
        assert_equal "https://assethost.com/ssl_prefix", CloudfrontAssetHost.asset_host('style.css', request)
      end

      should "not use the ssl_prefix for non-stylesheets requested over https" do
        CloudfrontAssetHost.ssl_prefix = "ssl_prefix"
        request = stub(:headers => {}, :protocol => 'https://')
        assert_equal "https://assethost.com", CloudfrontAssetHost.asset_host('image.png', request)
      end

      should "not use the ssl_prefix for stylesheets not requested over http" do
        CloudfrontAssetHost.ssl_prefix = "ssl_prefix"
        request = stub(:headers => {}, :protocol => 'http://')
        assert_equal "http://assethost.com", CloudfrontAssetHost.asset_host('style.css', request)
      end

      context "when taking the headers into account" do

        should "not support gzip for images" do
          request = stub(:headers => {'User-Agent' => 'Mozilla/5.0', 'Accept-Encoding' => 'gzip, compress'}, :protocol => 'http://')
          source  = "/images/logo.png"
          assert_equal "http://assethost.com", CloudfrontAssetHost.asset_host(source, request)
        end

        should "support gzip for IE" do
          request = stub(:headers => {'User-Agent' => 'Mozilla/4.0 (compatible; MSIE 8.0)', 'Accept-Encoding' => 'gzip, compress'}, :protocol => 'http://')
          assert_equal "http://assethost.com/gz", CloudfrontAssetHost.asset_host(@source, request)
        end

        should "support gzip for modern browsers" do
          request = stub(:headers => {'User-Agent' => 'Mozilla/5.0', 'Accept-Encoding' => 'gzip, compress'}, :protocol => 'http://')
          assert_equal "http://assethost.com/gz", CloudfrontAssetHost.asset_host(@source, request)
        end

        should "support not support gzip for Netscape 4" do
          request = stub(:headers => {'User-Agent' => 'Mozilla/4.0', 'Accept-Encoding' => 'gzip, compress'}, :protocol => 'http://')
          assert_equal "http://assethost.com", CloudfrontAssetHost.asset_host(@source, request)
        end

        should "require gzip in accept-encoding" do
          request = stub(:headers => {'User-Agent' => 'Mozilla/5.0'}, :protocol => 'http://')
          assert_equal "http://assethost.com", CloudfrontAssetHost.asset_host(@source, request)
        end

      end

    end
  end

  context "An enabled and configured plugin" do
    setup do
      CloudfrontAssetHost.configure do |config|
        config.enabled = true
        config.cname  = "assethost.com"
        config.bucket = "bucketname"
        config.key_prefix = ""
      end
    end

    should "set the asset_host" do
      assert ActionController::Base.asset_host.is_a?(Proc)
    end

    should "alias methods in asset-tag-helper" do
      assert ActionView::Helpers::AssetTagHelper.private_method_defined?('rails_asset_id_without_cloudfront')
      assert ActionView::Helpers::AssetTagHelper.private_method_defined?('rewrite_asset_path_without_cloudfront')
      assert ActionView::Helpers::AssetTagHelper.private_method_defined?('rails_asset_id')
      assert ActionView::Helpers::AssetTagHelper.private_method_defined?('rewrite_asset_path')
    end
  end

  context "An improperly configured plugin" do
    should "complain about bucket not being set" do
      assert_raise(RuntimeError) {
        CloudfrontAssetHost.configure do |config|
          config.enabled = false
          config.cname = "assethost.com"
          config.bucket = nil
        end
      }
    end

    should "complain about missing s3-config" do
      assert_raise(RuntimeError) {
        CloudfrontAssetHost.configure do |config|
          config.enabled = false
          config.cname = "assethost.com"
          config.bucket = "bucketname"
          config.s3_config = "bogus"
        end
      }
    end
  end

  should "respect custom asset_dirs" do
    CloudfrontAssetHost.configure do |config|
      config.bucket = "bucketname"
      config.asset_dirs = %w(custom)
    end
    assert_equal %w(custom), CloudfrontAssetHost.asset_dirs
  end

end
