
# ---------------------------------------------------------------------------
# CommentBox, copied from the example application
# ---------------------------------------------------------------------------

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
    div.comment_box do          # just like <div class="commentBox">
      h2 { "Feedback is really awesome!" }

      CommentList comments: [*state.comments]
      CommentForm submit_comment: lambda { |comment|
        state.comments!.push(send_comment_to_server(comment))
      }
    end
  end
end

class CommentList < React::Component::Base

  param :comments, type: Array

  def render
    div.comment_list do
      params.comments.last(10).each do |comment|
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

      form do
        input
          .author_name(type: :text, value: state.author, placeholder: "Username")
          .on(:change) { |e| state.author! e.target.value }
        span do
          input(type: :text, value: state.text, placeholder: "Say something...")
            .on(:change) { |e| state.text! e.target.value }
        end
      input(type: :submit, value: "Post")
        .on(:click) { |e|
          e.prevent_default
          params.submit_comment author: state.author, text: (state.text! "")
        }
        # div.preview do
        #   "PREVIEW".span
        #   Comment author: state.author, text: state.text
        # end
      end

    end
  end
end

class Comment < React::Component::Base

  param :author
  param :text

  def render
    div.comment {
      span.author { "#{params.author}:" }
      span.text   { params.text }
    # div.comment do
    #   span.comment_author { "#{params.author}: " }
    #   Showdown markup: params.text
    # end
    }
  end

end

class Showdown < React::Component::Base

  param :markup

  def render
    @converter ||= Native(`new Showdown.converter()`)
    raw_markup = @converter.makeHtml(params.markup) if params.markup

    span.markdown(dangerously_set_inner_HTML: {__html: raw_markup})
  end

end







