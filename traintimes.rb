require 'rubygems'

require 'twitter'
require 'open-uri'
require 'rubyful_soup'

require File.join(File.dirname(__FILE__), 'helpers', 'config_store')
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

  puts <<EOS
Visit #{oauth.request_token.authorize_url} in your browser to authorize the app,
then enter the PIN you are given:
EOS

  pin = STDIN.readline.chomp
  config.update({ 'pin' => pin })
  exit('Run this script again, now that you are authorised')
end

trains = YAML::load(File.read(File.join(File.dirname(__FILE__), 'trains.yml')))
hours = trains.keys.collect{ |time| time.split(':')[0].to_i }

if hours.include?(Time.now.hour)
  train = trains.select{ |k, v| (k.split(':')[0].to_i == Time.now.utc.hour) }

  trains.each do |time|
    if (Time.parse(time[0]).hour == Time.now.hour)
      info = time[1][:info]
      url = time[1][:url]

      # Digest the page and DM me the details
      open(url) do |page|
        page_content = page.read()
        soup = BeautifulSoup.new(page_content)
        result = soup.find('a', :attrs => {'class' => 'status'}).parent
        result.each do |tag|
          tag = tag.to_s
          if tag.include?(time[0].to_s)
            next if tag.include?('changes')

            status_text = soup.find('a', :attrs => {'class' => 'status'}).to_s.gsub(/<\/?[^>]*>/, '')
            dm = tag.to_s.gsub(/<\/?[^>]*>/, '').gsub('%ndash', '-').gsub(/[\t|\n]/,'').split('iCal')[0].chop + " *#{status_text}* " + ' ~ [info here]'
            dm = dm.gsub(/\s+/, ' ')
            puts "Sending dm: #{dm}..."
            twitter.direct_message_create('suttree', dm)
          end
        end
      end
    end
  end
end
