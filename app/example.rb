require 'opal'
require 'browser/interval'
require 'jquery'
require 'opal-jquery'
require "json"
require 'reactive-ruby'
require 'commentbox'

# Dev-mode hot reloader!
require 'opal_hot_reloader'
OpalHotReloader.listen(25222, true)

if ! $loaded # Only set this up once
  $loaded = true
  Document.ready? do
    React.render(
      React.create_element(App),
      Element['#content']
    )
  end
end

class Navigation < React::Component::Base

  param :current_page
  param :goto_page, type: Proc

  def render
    pages = ['Intro', 'Triage', 'Bracket', 'Chat', 'About']
    div.nav {
      pages.each do |pagename|
        div.nav_item {
          if params.current_page == pagename
            a.current(href: "#") { "#{pagename}" }
          else
            a(href: '#') { pagename }
              .on(:click) { params.goto_page(pagename) }
          end
        }
      end
    }
  end

end

class Heading < React::Component::Base
  def render
    div.heading {
      img.logo(src: 'white_elephant.png')
      div.title_box {
        span.title { "White Elephant Gift Selector" }
        span.subtitle { "The Interactive Guide to the Perfect Gift" }
      }
    }
  end
end

class App < React::Component::Base
  define_state :app_state
  before_mount do
    state.app_state!({
      page: 'Intro',
      possible_products: [],
      product: {
        title: "Not Really A Product",
        img: '',
        url: '',
        price: "12.23"
      }
    })
    @product_queue = []
    get_random_product do |product|
      @product_queue << product
      next_product
    end
  end

  def render
    current_page = state.app_state[:page]

    div.app do
      div.header do
        Heading {}
        Navigation current_page: current_page, goto_page: method(:goto_page)
      end
      div.page do

        # Dispatch to a component based on the current page
        case current_page
        when "Intro"
          IntroPage goto_page: method(:goto_page)
        when "Triage"
          Triage(
            current_product:   state.app_state[:product],
            possible_products: state.app_state[:possible_products],
            keep_product:      method(:keep_product),
            remove_product:    method(:remove_product),
            next_product:      method(:next_product)
          )
        when "Bracket"
          Bracket(
            possible_products: state.app_state[:possible_products],
            keep_product:      lambda { |product| keep_product(product, false) },
            remove_product:    method(:remove_product)
          )
        when "Chat"
          CommentBox app_state: state.app_state
        when "About"
          AboutPage {}
        else
          h2 { "ERROR" }
        end
      end
    end
  end

  def goto_page(pagename)
    state.app_state![:page] = pagename
  end

  def keep_product(product, get_next = true)
    state.app_state![:possible_products] << product
    next_product if get_next
  end

  def remove_product(product)
    state.app_state![:possible_products].delete(product)
  end

  def get_random_product
    puts "Getting random product..."
    HTTP.get('/random_product.json') do |response|
      puts "Got response"
      if response.ok?
        product = JSON.parse(response.body)
        # Create an Image to pre-fetch it :)
        yield product
        puts "Pre-fetching image #{product[:img]}"
        image = Element.new(:img)
        image[:src] = product[:img]
      else
        puts "failed with status #{response.status_code}"
      end
    end
  end

  # The API is pretty slow, so we'll pre-fetch a bunch of products
  def fill_product_queue
    if @product_queue.count < 20
      get_random_product do |product|
        @product_queue << product
        fill_product_queue
      end
    end
  end

  def next_product
    product = @product_queue.shift
    state.app_state![:product] = product
    state.app_state! # Why do I need this?
    fill_product_queue
  end
end

class AboutPage < React::Component::Base
  def render
    div.about_page {
      Showdown markup: <<-END.gsub(/^\ {8}/, "")
        ## About: What is this thing?!

        This gift selector is two things. First, a fun way to pick out some
        fabulous gifts. Obviously? :)

        Second it is a learning environment for experimenting in some random
        web technology. The original version was implemented in
        [ClojureScript](https://github.com/clojure/clojurescript).

        For this incarnation we are using [Opal](http://opalrb.org) and
        [React.rb](http://reactrb.org), along with some cool dev-mode tools
        such as
        [opal-hot-reloader](https://github.com/fkchang/opal-hot-reloader).

        Check out and mess with the source code on
        [Github](https://github.com/awwaiid/reactrb-elephant)

        Follow me on twitter, [@awwaiid](https://twitter.com/awwaiid), if you
        like nonsense and occasional photos of pugs.

        Contributors include, and many thanks to, Elizabeth McCollum and Danny
        Cohen.
      END
    }
  end
end

class IntroPage < React::Component::Base
  param :goto_page, type: Proc
  def render
    div.intro_page {
      Showdown markup: <<-END.gsub(/^\ {8}/, "")
        ## Salutations, seeker of gifts!

        You have the distinct honor of attending a **White Elephant Gift
        Exchange Party!** A party in which each participant brings with them a
        delicious bit of wonder so enticing that others will snatch it up,
        returning to their castle to discover all too late how much care and
        feeding a White Elephant actually requires.

        It is **VITAL** that you show up with a great gift. But there are so
        many choices!  What to do? What makes the perfect White Elephant Gift?!

        **Triage Phase:** We'll look through a bunch of random products,
        keeping the potential gifts. Pick out 16 gifts. You decide what is
        worthy for consideration...  Funny? Work-appropriate? Kinda Awesome?

        **Tournament Phase:** Now that you have some potentials, it's time to
        pick THE BEST! Two enter the ring, one leaves... in the end there can
        be only one!
      END

      a(href:'#') { "Begin the triage!" }.on(:click) { params.goto_page('Triage') }
    }
  end
end

class Triage < React::Component::Base

  param :current_product
  param :possible_products

  param :keep_product, type: Proc
  param :next_product, type: Proc
  param :remove_product, type: Proc

  def render
    div.triage {

      h2 { "Triage: Build Your Product List" }
      h3 { "Is this a white-elephant-gift worth considering?" }

      div.triage_products {
        div.current {
          Product(
            product: params.current_product,
            actions: [
              { text: "Not for me", action: -> { next_product } },
              { text: "Keep it!",   action: -> { keep_product } }
            ]
          )
        }

        div.contenders {
          params.possible_products.each do |product|
            Product(
              product: product,
              actions: [
                # { text: "X", action: -> { remove_product(product) } }
              ]
            )
          end
        }
      }
    }
  end

  def keep_product
    params.keep_product(params.current_product)
  end

  def next_product
    puts "triage: next_product"
    params.next_product
  end
end

class Product < React::Component::Base

  param :product
  param :actions

  def render
    # puts "Product: render [#{params.product[:title]}]"
    div.product {
      a.buy_link(href: params.product[:url], target: '_blank') {
        img.photo(src: params.product[:img])
        div.desc {
            h3.title { params.product[:title] }
            span.price { params.product[:price] }
            span.comma { " " }
          }
      }
      div {
        params.actions.each do |action|
          button.action { action[:text] }.on(:click) { action[:action].() }
        end
      }
    }

  end
end

class Bracket < React::Component::Base
  param :possible_products
  param :remove_product, type: Proc
  param :keep_product, type: Proc

  def render
    product_a = params.possible_products[0]
    product_b = params.possible_products[1]

    div.bracket {

      h2 { "Bracket: There Can Be Only One!" }

      if params.possible_products.count == 1
        h2 { "WE HAVE A WINNER!" }
        Product product: product_a, actions: []
      else

        div { "There are #{ params.possible_products.count - 2 } matches remaining" }

        div.contenders {
          params.possible_products.each do |product|
            Product(
              product: product,
              actions: [ ]
            )
          end
        }

        div.comparison {
          Product(
            product: product_a,
            actions: [
              { text: "This one", action: -> { keep_winner(product_a, product_b) } }
            ]
          )

          Product(
            product: product_b,
            actions: [
              { text: "This one", action: -> { keep_winner(product_b, product_a) } }
            ]
          )
        }
      end
    }
  end

  def keep_winner(winner_product, loser_product)
    remove_product(winner_product)
    remove_product(loser_product)
    keep_product(winner_product)
  end
end

