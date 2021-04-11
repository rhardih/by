require 'httparty'
require 'nokogiri'

NDK = Struct.new(:name, :version, :url, :sha1)
ndks = []

response = HTTParty.get("https://android-dot-devsite-v2-prod.appspot.com/ndk/downloads/older_releases_cf9eeb402fc5691b390be41c2c1f4a280be6ab60d99eb1606e63014b218845ad.frame")

document = Nokogiri.HTML(response.body)
downloadsEl = document.css("body > div.all-downloads").first

# All NDKs are flat-listed under this single parent element, but they each have
# three associated elements; <h3>, <devsite-code> & <table>.

info = []

filtered = downloadsEl.children.each do |node|
  case node.name
  when "h3"
    ndks << NDK.new(node.text)
  when "pre"
    md = /\d+\.\d+\.\d+/.match(node.text)
    ndks[-1].version = md[0]
  when "table"
    ndks[-1].url = node.xpath("tr[5]/td[2]/a/@href").first.value
    ndks[-1].sha1 = node.xpath("tr[5]/td[4]").text
  end
end
