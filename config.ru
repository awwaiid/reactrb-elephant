# config.ru
require 'bundler'
Bundler.require

require 'open-uri'
require 'sass/plugin/rack'

# Opal::Processor.source_map_enabled = true

opal = Opal::Server.new {|s|
  s.append_path './app'
  s.main = 'example'
  s.debug = true
  # s.source_map = true
}

# map opal.source_maps.prefix do
#   run opal.source_maps
# end

map '/assets' do
  run opal.sprockets
end

# Sass::Plugin.options[:style] = :compressed
use Sass::Plugin::Rack

get '/random_product.json' do
  if !$results_count
    user_agent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_7_0) AppleWebKit/535.2 (KHTML, like Gecko) Chrome/15.0.854.0 Safari/535.2"
    page_url = 'https://www.blinq.com/search/go?p=Q&lbc=blinq&ts=custom&w=*&isort=newest&method=and&view=grid&af=price%3A%5B0%2C2000%5D%0A'
    page = Nokogiri::HTML(open(page_url, 'User-Agent' => user_agent))
    $results_count = page.css('.results-text').first.text.gsub(/\D/, '').to_i
    puts "Result count: #{$results_count}"
  end
  offset = rand($results_count)
  low_price = 0
  high_price = 20_00
  random_product_url = "https://www.blinq.com/search/go?p=Q&lbc=blinq&w=*&" +
    "af=price%3a%5b#{low_price}%2c#{high_price}%5d" +
    "&isort=price&method=and&view=grid&ts=infinitescroll&" +
    "srt=#{offset}"

  page = Nokogiri::HTML(open(random_product_url))

  title = page.css('li h3.tile-desc').first.text
  img = page.css('li div.tile-img img').first['src']
  url = page.css('li a.tile-link').first['href']
  price = page.css('li span.live_saleprice').first.text

  JSON.generate({
    title: title,
    img: img,
    url: url,
    price: price
  })
end

get '/comments.json' do
  comments = JSON.parse(open("./_comments.json").read)
  JSON.generate(comments)
end

get '/comments.js' do
  content_type "application/javascript"
  comments = JSON.parse(open("./_comments.json").read)
  "window.initial_comments = #{JSON.generate(comments)}"
end

post "/comments.json" do
  comments = JSON.parse(open("./_comments.json").read)
  comments.push(JSON.parse(request.body.read))
  File.write('./_comments.json', JSON.pretty_generate(comments, :indent => '    '))
  JSON.generate(comments.last(10))
end


get '/' do
  <<-HTML
    <!doctype html>
    <html>
      <head>
        <title>White Elephant Gift Selector</title>
        <link rel="stylesheet" href="stylesheets/normalize.css" />
        <link rel="stylesheet" href="stylesheets/base.css" />
        <script src="http://cdnjs.cloudflare.com/ajax/libs/showdown/0.3.1/showdown.min.js"></script>
        <script src="/assets/example.js"></script>
        <script src="/comments.js"></script>
        <script>#{Opal::Processor.load_asset_code(opal.sprockets, "example.js")}</script>
      </head>
      <body>
        <!-- <textarea id="code"></textarea>
        <input type=submit id="execute"> -->
        <div id="content"></div>
      </body>
    </html>
  HTML
end

run Sinatra::Application

