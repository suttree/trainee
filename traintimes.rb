require 'rubygems'
require 'rubyful_soup'
require 'open-uri'
require 'twitter'
require File.join(File.dirname(__FILE__), 'helpers', 'config_store')

# Run via a cron job at 7:45am and 5:30pm

# load the page for the 8:13 train and the 6.23 train
# scrape the results
# send me a DM with the line containing those trains

config = ConfigStore.new(File.join(File.dirname(__FILE__), '.twitter'))
oauth = Twitter::OAuth.new(config['token'], config['secret'])

if config['atoken'] && config['asecret']
  oauth.authorize_from_access(config['atoken'], config['asecret'])
  twitter = Twitter::Base.new(oauth)
  
elsif config['rtoken'] && config['rsecret']  
  oauth.authorize_from_request(config['rtoken'], config['rsecret'], config['pin'])
  twitter = Twitter::Base.new(oauth)
  
  config.update({
    'atoken'  => oauth.access_token.token,
    'asecret' => oauth.access_token.secret,
  }).delete('rtoken', 'rsecret')
else
  config.update({
      'rtoken'  => oauth.request_token.token,
      'rsecret' => oauth.request_token.secret,
    })

  # A better implementation is available at http://gist.github.com/524376
  puts "Authorize this request at the following url:"
  puts oauth.request_token.authorize_url
  puts "Then add an entry for ping to the .twitter config store"
end
  

trains = {
  :morning => {
    :time => '08:13',
    :info => 'Dartford to Charing Cross',
    :url => 'http://traintimes.org.uk/dartford/london+charing+cross/08:00/today/overtake=1'
  },
  :evening => {
    :time => '18:23',
    :info => 'Charing Cross to Dartford',
    :url => 'http://traintimes.org.uk/london+charing+cross/dartford/18:15/today/overtake=1'
  },
  :test => {
    :time => '22:39',
    :info => 'Charing Test to Darttest',
    :url => 'http://traintimes.org.uk/london+charing+cross/dartford/22:20/today/overtake=1'
  }
}

# If we're running at 5pm, look for evening trains. Otherwise, look for morning trains.
# - todo, make this better by putting all the trains data into a config file
# -       and use the :time key to check what trains to search for
#
# Run @hourly, check each of the hour keys in the trains hash, then run the rest...
hour = Time.now.hour
key = (hour == 17 ? :evening : :morning)

url = trains[key][:url]
info = trains[key][:info]
time = trains[key][:time]

# Digest the page and DM me the details
# - todo, only DM me if there are problems with the train
open(url) do |page|
  page_content = page.read()
  soup = BeautifulSoup.new(page_content)
  result = soup.find_all('p', :attrs => {'align' => 'center'})[0].find_all('li')
  result.each do |tag|
    if tag.to_s.include?(time)
      dm = tag.to_s.gsub(/<\/?[^>]*>/, '').gsub('%ndash', '-').split('iCal')[0].chop + ' ~ ' + info
      twitter.direct_message_create('suttree', dm)
    end
  end
end
