require 'test_helper'

class CssRewriterTest < Test::Unit::TestCase

  context "The CssRewriter" do

    setup do
      CloudfrontAssetHost.configure do |config|
        config.cname  = "assethost.com"
        config.bucket = "bucketname"
        config.key_prefix = ""
        config.enabled = false
        config.asset_host_without_cloudfront = 'www.example.com'
      end

      @stylesheet_path = File.join(Rails.public_path, 'stylesheets', 'style.css')
      CloudfrontAssetHost::Uploader.stubs(:current_paths).returns([File.join(Rails.public_path, 'images','image.png')])
    end

    should "rewrite a single css file" do
      tmp = CloudfrontAssetHost::CssRewriter.rewrite_stylesheet(@stylesheet_path)
      contents = File.read(tmp.path)
      contents = contents.split("\n")
      contents[0..5].each do |line|
        assert_equal "body { background-image: url(http://assethost.com/d41d8cd98/images/image.png); }", line
      end
      assert_equal "body { background-image: url(http://assethost.com/d41d8cd98/images/image.png#223145); }", contents[6]
      assert_equal "body { background-image: url(http://www.example.com/strange_asset/image.png#223145); }", contents[7]
    end

    should "use https urls if writing an ssl stylesheet" do
      tmp = CloudfrontAssetHost::CssRewriter.rewrite_stylesheet(@stylesheet_path, true)
      contents = File.read(tmp.path)
      contents = contents.split("\n")
      contents[0..5].each do |line|
        assert_equal "body { background-image: url(https://assethost.com/d41d8cd98/images/image.png); }", line
      end
      assert_equal "body { background-image: url(https://assethost.com/d41d8cd98/images/image.png#223145); }", contents[6]
      assert_equal "body { background-image: url(https://www.example.com/strange_asset/image.png#223145); }", contents[7]
    end

  end

end
