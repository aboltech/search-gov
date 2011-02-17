require "base64"
require "rubygems"
require "spec"
begin
  gem 'sauce', '0.15.1'
  require 'sauce'
rescue LoadError => e
  $stderr.puts "To enable sauce integration, run 'gem install sauce -v 0.15.1"
  raise e
end

Sauce.config do |conf|
  conf.browser_url = "http://demo:***REMOVED***@searchdemo.usa.gov"
  conf.username = "usa_search"
  conf.access_key = "5060039c-fa2b-403c-9fef-617142894173"
end

class Browser < Struct.new(:os, :browser, :browser_version)
  def to_s
    "#{browser} #{browser_version} (#{os})"
  end
end

class ScreenshotExampleGroup < Spec::Example::ExampleGroup
  attr_reader :selenium
  alias_method :page, :selenium

  before :each do
    description = [self.class.description, self.description].join(" ")
    @selenium = Sauce::Selenium.new({:os => @browser.os, :browser => @browser.browser, :browser_version => @browser.browser_version, :job_name => "#{description}"})
    @selenium.start
  end

  after :each do
    @selenium.stop
  end

  Spec::Example::ExampleGroupFactory.register(:screenshot, self)

  def capture_page(page, page_name)
    page.wait_for_page_to_load
    @@steps ||= Hash.new {|h,k| h[k] = 0}
    browser_hash = JSON.parse(page.browser_string)
    browser_identifier = "#{browser_hash["browser"]}-#{browser_hash["browser-version"]}-#{browser_hash["os"]}"
    report_path = File.dirname(__FILE__) + "/../report/" + browser_identifier

    png = page.capture_screenshot_to_string
    FileUtils.mkdir_p(report_path)
    File.open(report_path + "/%03i-%s-screenshot.png" % [@@steps[browser_identifier]+=1, page_name], 'wb') do |f|
      f.write(Base64.decode64(png))
      f.close
    end
  end

end

