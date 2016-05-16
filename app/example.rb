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
    next_product
  end

  def render
    div.app do
      div.header do
        h1 { "White Elephant Gift Selector" }
        pages = ['Intro', 'Triage', 'Bracket', 'Feedback', 'About']
        div.nav {
          pages.each do |pagename|
            div.nav_item {
              a(href: "#") { "#{pagename}" }.on(:click) {
                state.app_state![:page] = pagename
              }
            }
          end
        }
      end
      div.page do
        current_page = state.app_state[:page]
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
            keep_product:      method(:keep_product),
            remove_product:    method(:remove_product)
          )
        when "Feedback"
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

  def keep_product(product)
    state.app_state![:possible_products] << product
    next_product
  end

  def remove_product(product)
    state.app_state![:possible_products].delete(product)
  end

  def next_product
    puts "app: next_product"
    HTTP.get('/random_product.json') do |response|
      if response.ok?
        product = JSON.parse(response.body)
        state.app_state![:product] = product
        state.app_state! # Why do I need this?
      else
        puts "failed with status #{response.status_code}"
      end
    end
  end
end

class AboutPage < React::Component::Base
  def render
    div.about_page {
      Showdown markup: <<-END.gsub(/^\ {8}/, "")
        ## About: What is this thing?!

        I previously built this in ClojureScript/React. This is a re-write
        using Opal/ReactRB!

        [Github](https://github.com/awwaiid/reactrb-elephant) -
        [@awwaiid](https://twitter.com/awwaiid)
      END
    }
  end
end

class IntroPage < React::Component::Base
  param :goto_page, type: Proc
  def render
    div.intro_page {
      Showdown markup: <<-END.gsub(/^\ {8}/, "")
        You're going to a **White Elephant Gift Exchange Party!** It is VITAL
        that you show up with a great gift. But there are so many choices!
        What to do?

        **Triage Phase:** We'll look through a bunch of random products,
        keeping the potential gifts. Pick out at least 16. You decide what is
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
                { text: "X", action: -> { remove_product(product) } }
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
    puts "Product: render [#{params.product[:title]}]"
    div.product {
      a.buy_link(href: params.product[:url], target: '_blank') {
        img.photo(src: params.product[:img])
        div.desc {
            h3.title { params.product[:title] }
            span.price { params.product[:price] }
            span.comma { " " }
          }
      }
      params.actions.each do |action|
        button.action { action[:text] }.on(:click) { action[:action].() }
      end
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

