require 'opal'
require 'browser/interval'
require 'jquery'
require 'opal-jquery'
require "json"
require 'reactive-ruby'
require 'liveloader'

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
  end

  def render
    div do
      div.header do
        h1 { "White Elephant Gift Selector" }
        pages = ['Intro', 'Triage', 'Feedback', 'About']
        div.nav {
          pages.each do |pagename|
            div.nav_item {
              a(href: "#") { pagename }.on(:click) {
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
          IntroPage goto_page: method(:goto_page) # to_proc stops warning
        when "Triage"
          Triage(
            current_product:   state.app_state[:product],
            possible_products: state.app_state[:possible_products],
            keep_product:      method(:keep_product),
            remove_product:    method(:remove_product),
            next_product:      method(:next_product))
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
    div {
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
    div {
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
    div {
#   ; (if (< (count (@app-state :possible-products)) 1)
#   ;   (secretary/dispatch! "/"))
#   [:div

      h2 { "Triage: Build Your Product List" }
      h3 { "Is this a white-elephant-gift worth considering?" }

#    [possible-products-count]
#    (if (>= (count (@app-state :possible-products)) 16)
#       [:div [:a.onward {:href "/tournament"
#                         :onClick #( do (
#          (swap! app-state update-in [:possible-products] shuffle)

#   (secretary/dispatch! "/tournament"))

#                                    )
#                         } (str (count (@app-state :possible-products)) " is enough... Tournament time!")]
#    [:br]])

      div.triage {
        div.current {
          Product(product: params.current_product)
          a.another(href:'#') { "Not For Me" }.on(:click) { next_product }
          br
          a.thisone(href:'#') { "Keep it!" }.on(:click) { keep_product }
        }

        div.contenders {
          params.possible_products.each do |product|
            Product(product: product)
            a(href:'#') { "X" }.on(:click) { remove_product(product) }
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

  def render
    puts "Product: render [#{params.product}]"
    div.product {
      img.photo(src: params.product[:img])
      div.desc {
        h3.title { params.product[:title] }
        span.price { params.product[:price] }
        ", ".span.comma
        a.buy_link(href: params.product[:url], target: '_blank') { "Buy it on BLINQ" }
      }
    }
  end
end

class CommentBox < React::Component::Base
  param :url
  param :poll_interval
  param :app_state

  define_state(:comments) { JSON.from_object(`window.initial_comments`) }

  before_mount do
    state.comments! JSON.from_object(`window.initial_comments`)
    @url = 'comments.json'
    @poll_interval = 2

    @fetcher = every(@poll_interval) do          # we use the opal browser utility to call the server every poll_interval seconds
      HTTP.get(@url) do |response|               # notice that params poll_interval, and url are accessed as instance methods
        if response.ok?
          puts "Updating comments..."
          state.comments! JSON.parse(response.body)   # comments!(value) updates the state and notifies react of the state change
        else
          puts "failed with status #{response.status_code}"
        end
      end
    end
  end

  after_mount do
    @fetcher.start
  end

  before_unmount do
    @fetcher.stop
  end

  def send_comment_to_server(comment)
    HTTP.post(@url, payload: comment) do |response|
      puts "failed with status #{response.status_code}" unless response.ok?
    end
    comment
  end

  def render
    div class: "commentBox" do          # just like <div class="commentBox">
      h2 { "Feedback is really awesome!" }

      CommentForm submit_comment: lambda { |comment|
        state.comments!.unshift(send_comment_to_server(comment))
      }
      CommentList comments: [*state.comments]
    end
  end
end

# Our second component!

class CommentList < React::Component::Base

  param :comments, type: Array

  def render
    div.commentList.and_another_class.and_another do
      params.comments.each do |comment|
        Comment author: comment[:author], text: comment[:text] # , hash: comment
      end
    end
  end

end

class CommentForm < React::Component::Base

  param :submit_comment, type: Proc
  define_state :author, :text

  def render
    div do
      div do
        input.author_name(type: :text, value: state.author, placeholder: "Your name")
          .on(:change) { |e| state.author! e.target.value }
      end

      div do
        div do
          textarea(value: state.text, placeholder: "Say something...", rows: 6, cols: 60)
            .on(:change) { |e| state.text! e.target.value }
        end
        div.preview do
          "PREVIEW".span
          Comment author: state.author, text: state.text
        end
      end

      button { "Post" }
        .on(:click) {
          params.submit_comment author: (state.author! ""), text: (state.text! "")
        }
    end
  end
end

class Comment < React::Component::Base

  param :author
  param :text

  def render
    div.comment do
      h2.comment_author { params.author }
      Showdown markup: params.text
    end
  end

end

class Showdown < React::Component::Base

  param :markup

  def render
    @converter ||= Native(`new Showdown.converter()`)
    raw_markup = @converter.makeHtml(params.markup) if params.markup

    span(dangerously_set_inner_HTML: {__html: raw_markup})
  end

end







