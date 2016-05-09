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
      span { "White Elephant Gift Selector" }
      pages = ['Intro', 'Triage', 'Feedback', 'About']
      ul {
        pages.each do |pagename|
          li {
            a(href: "#") { pagename }.on(:click) {
              state.app_state![:page] = pagename
            }
          }
        end
      }
      current_page = state.app_state[:page]
      case current_page
      when "Intro"
        IntroPage goto_page: method(:goto_page) # to_proc stops warning
      when "Triage"
        Triage(
          current_product: state.app_state[:product],
          possible_products: state.app_state[:possible_products],
          keep_product: method(:keep_product),
          remove_product: method(:remove_product),
          next_product: method(:next_product))
      when "Feedback"
        CommentBox app_state: state.app_state
      when "About"
        AboutPage {}
      else
        h2 { "ERROR" }
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
    state.app_state![:product] = {
      title: "Other thing",
      img: '',
      url: '',
      price: rand(20).to_s }
  end
end

class AboutPage < React::Component::Base
  def render
    div {
      h2 { "About: What is this thing?!" }
      p { "I (Brock - awwaiid@thelackthereof.org) work for blinq.com, and
           thought it would be cool to make a gift picker in my free time." }
      a(href: "https://github.com/awwaiid/reactrb-elephant") { "Github" }
      span { " - " }
      a(href: "https://twitter.com/awwaiid") { "@awwaiid" }
    }
  end
end

class IntroPage < React::Component::Base
  param :goto_page, type: Proc
  def render
    div {
      p { "You're going to a White Elephant Gift Exchange Party!  It is
           VITAL that you show up with a great gift. But there are so many choices!
           What to do?" }
      p {
        strong { "Triage Phase: " }
        span { "We'll look through a bunch of random products, keeping the potential
                gifts. Pick out at least 16. You decide what is worthy for consideration...
                Funny? Work-appropriate? Kinda Awesome?" }
      }
      p {
        strong { "Tournament Phase: " }
        span { "Now that you have some potentials, it's time to pick THE BEST! Two enter
                the ring, one leaves... in the end there can be only one!" }
      }
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
      h2 { 'Triage' }
#   ; (if (< (count (@app-state :possible-products)) 1)
#   ;   (secretary/dispatch! "/"))
#   [:div

      h2 { "Triage: Build Your Product List" }

#    [possible-products-count]
#    (if (>= (count (@app-state :possible-products)) 16)
#       [:div [:a.onward {:href "/tournament"
#                         :onClick #( do (
#          (swap! app-state update-in [:possible-products] shuffle)

#   (secretary/dispatch! "/tournament"))

#                                    )
#                         } (str (count (@app-state :possible-products)) " is enough... Tournament time!")]
#    [:br]])

      div.current {
        h3 { "Worth Adding To Your List?" }
        Product(product: params.current_product)
        a.another(href:'#') { "Not For Me" }.on(:click) { next_product }
        br
        a.thisone(href:'#') { "Keep it!" }.on(:click) { keep_product }
      }

      div.contenders {
        params.possible_products.each do |product|
          Product(product: product)
          a(href:'#') { "remove" }.on(:click) { remove_product(product) }
        end
      }
    }
  end

  def keep_product
    params.keep_product(params.current_product)
  end

  def next_product
    params.next_product
  end

# (defn save-product []
#   (if (@app-state :product)
#     (if (not (seq-contains? (map :title (@app-state :possible-products)) (get-in @app-state [:product :title])))
#       (do (
#         (swap! app-state update-in [:possible-products] conj (@app-state :product))
#         (swap! app-state assoc :product {})
#         ; (swap! app-state update-in [:possible-products] shuffle))
#           ))))
#     (next-product))
end

class Product < React::Component::Base
  param :product
  def render
    puts "Product: render [#{params.product}]"
    div.product {
      img.photo(src: params.product[:img])
      div.desc {
        h3.title { params.product[:title] }
        div.price { "Price: $" + params.product[:price] }
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

  # finally our component should be a good citizen and stop the polling when its unmounted

  before_unmount do
    @fetcher.stop
  end

  # components can have their own methods like any other class
  # in this case we receive a new comment and send it the server

  def send_comment_to_server(comment)
    HTTP.post(@url, payload: comment) do |response|
      puts "failed with status #{response.status_code}" unless response.ok?
    end
    comment
  end

  # every component must implement a render method.  The method must generate a single
  # react virtual DOM element.  React compares the output of each render and determines
  # the minimum actual DOM update needed.

  # A very common mistake is to try generate two or more elements (or none at all.) Either case will
  # throw an error.  Just remember that there is already a DOM node waiting for the output of the render
  # hence the need for exactly one element per render.

  def render
    puts "Rendering CommentBox"

    div class: "commentBox" do          # just like <div class="commentBox">

      h2 { "Feedback is really awesome!" }

      puts "Re-rendering CommentBox"
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
    puts "Rendering #{params.comments.count} comments"

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

        "Author: ".span # Note the shorthand for span { "Author" }
        # You can do this with br, span, th, td, and para (for p) tags


        input.author_name(type: :text, value: state.author, placeholder: "Your name", style: {width: "30%"})
          .on(:change) { |e| state.author! e.target.value }

      end

      div do
        # lets have some fun with the text.  Same deal as the author except we will use a text area...
        div(style: {float: :left, width: "50%"}) do
          textarea(value: state.text, placeholder: "Say something...", style: {width: "90%"}, rows: 30).
            on(:change) { |e| state.text! e.target.value }
        end
        # and lets use Showdown to allow for markdown, and display the mark down to the left of input
        # we will define Showdown later, and it will be our first reusable component, as we will use it twice.
        div(style: {float: :left, width: "50%"}) do
          Showdown markup: state.text
        end
      end

      # Finally lets give the use a button to submit changes.  Why not? We have come this far!
      # Notice how the submit_comment proc param allows us to be ignorant of how the update is made.

      # Notice that (author! "") updates author, but returns the current value.
      # This is usually the desired behavior in React as we are typically interested in state changes,
      # and before/after values, not simply doing a chained update of multiple variables.

      button { "Post" }.on(:click) { params.submit_comment author: (state.author! ""), text: (state.text! "") }

    end
  end
end

# Wow only two more components left!  This one is a breeze.  We just take the author, and text and display
# them.  We already know how to use our Showdown component to display the markdown so we can just reuse that.

class Comment

  include React::Component

  param :author
  param :text
  # param :hash, type: Hash

  def render
    div.comment do
      h2.comment_author { params.author } # NOTE: single underscores in haml style class names are converted to dashes
                                   # so comment_author becomes comment-author, but comment__author would be comment_author
                                   # this is handy for boot strap names like col-md-push-9 which can be written as col_md_push_9
      Showdown markup: params.text
    end
  end

end

# Last but not least here is our ShowDown Component

class Showdown

  include React::Component

  param :markup

  def render

    # we will use some Opal lowlevel stuff to interface to the javascript Showdown class
    # we only need to build the converter once, and then reuse it so we will use a plain old
    # instance variable to keep track of it.

    @converter ||= Native(`new Showdown.converter()`)

    # then we will take our markup param, and convert it to html

    raw_markup = @converter.makeHtml(params.markup) if params.markup

    # React.js takes a very dim view of passing raw html so its purposefully made
    # difficult so you won't do it by accident.  After all think of how dangerous what we
    # are doing right here is!

    # The span tag can be replaced by any tag that could sensibly take a child html element.
    # You could also use div, td, etc.

    span(dangerously_set_inner_HTML: {__html: raw_markup})

  end

end







