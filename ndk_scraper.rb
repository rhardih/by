require 'httparty'
require 'nokogiri'

NDK = Struct.new(:version, :url, :sha)
ndks = []

# Current LTS version
current_url = 'https://github.com/android/ndk/wiki'

response = HTTParty.get(current_url)
document = Nokogiri.HTML(response.body)

h3_current_lts = document.xpath('//*[@id="wiki-body"]/div/h3[text() = "Current LTS Release"]')
p_current_lts = h3_current_lts.xpath('following-sibling::p')
table_current_lts = h3_current_lts.xpath('following-sibling::table')

_, col1, _, col3 = table_current_lts.xpath('tbody/tr[td[1]="Linux"]/td')

current_lts_version = p_current_lts.first.text.split.first
current_lts_url = col1.xpath('a/@href').first.value
current_lts_sha = col3.text

ndks << NDK.new(current_lts_version, current_lts_url, current_lts_sha)

# Older versions
older_url = 'https://github.com/android/ndk/wiki/Unsupported-Downloads'

response = HTTParty.get(older_url)
document = Nokogiri.HTML(response.body)

# group = document.xpath('//*[@id="wiki-body"]/div/*[self::h3 or self::table]')
h3_versions = document.xpath('//*[@id="wiki-body"]/div/h3')

h3_versions.each do |h3_version|
  version = h3_version.text

  table = h3_version.xpath('following-sibling::table').first

  if table.nil?
    # The r10e and r9d are listed in an unordered list, without a sha, so they
    # have been manually calculated and hardcoded here

    missing_shas = {
      'r10e' => "f692681b007071103277f6edc6f91cb5c5494a32",
      'r9d' => "6d0cdb0b06eeafaa89890d05627aee89122b143f",
    }

    list = h3_version.xpath('following-sibling::ul')
    item = list.xpath('li[starts-with(.,"Linux")]')
    url = item.xpath('a/@href').first.value

    if version == 'r9d'
      # We don't want to support this version, because it's not packaged as a
      # .zip file, which means we can't peak into it's contents as easily
      next
    end

    ndks << NDK.new(version, url, missing_shas[version])
  else
    # Grab the url and sha from the table row that has Linux as platform
    _, col1, _, col3 = table.xpath('tbody/tr[td[1]="Linux"]/td')

    url = col1.xpath('a/@href').first.value
    sha = col3.text

    ndks << NDK.new(version, url, sha)
  end
end

pp ndks
