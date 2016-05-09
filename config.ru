# config.ru
require 'bundler'
Bundler.require

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

get '/random_product.json' do
  JSON.generate({
    title: "Many Other things, #" + rand(1000).to_s,
    img: '',
    url: '',
    price: rand(20).to_s
  })
end

# (defn fetch-url [url]
#   (enlive/html-resource (java.net.URL. url)))

# (defn random-product-url []
#   (let [offset (rand-int 9000)
#         low-price 0
#         high-price 2000]
#     (printf "Offset: %d\n" offset)
#     (str "https://www.blinq.com/search/go?p=Q&lbc=blinq&w=*&"
#          "af=price%3a%5b" low-price "%2c" high-price "%5d"
#          "&isort=price&method=and&view=grid&ts=infinitescroll&"
#          "srt=" offset)))

# (defn random-product
#   "Grab a random product, extracting out the essentials"
#   []
#   (let [page (fetch-url (random-product-url))
#         title (enlive/text (first
#                              (enlive/select
#                                page
#                                [[:li (enlive/nth-of-type 1)] :h3.tile-desc])))
#         img (get-in (first (enlive/select
#                              page
#                              [[:li (enlive/nth-of-type 1)] :div.tile-img :img])) [:attrs :src])
#         url (get-in (first (enlive/select
#                              page
#                              [[:li (enlive/nth-of-type 1)] :a.tile-link])) [:attrs :href])
#         price (enlive/text (first
#                              (enlive/select
#                                page
#                                [[:li (enlive/nth-of-type 1)] :span.live_saleprice])))]
#     (response {:img img
#                :title title
#                :brock 5
#                :price price
#                :url url})))

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
  comments.unshift(JSON.parse(request.body.read))
  File.write('./_comments.json', JSON.pretty_generate(comments, :indent => '    '))
  JSON.generate(comments)
end

get '/code.rb' do
  open("app/example.rb").read
end

get '/' do
  <<-HTML
    <!doctype html>
    <html>
      <head>
        <title>Hello React</title>
        <link rel="stylesheet" href="base.css" />
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
