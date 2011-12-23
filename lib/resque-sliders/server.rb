module Resque
  module Plugins
    module ResqueSliders
      module Server

        VIEW_PATH = File.join(File.dirname(__FILE__), 'server', 'views')
        PUBLIC_PATH = File.join(File.dirname(__FILE__), 'server', 'public')

        def self.registered(app)

          app.get '/sliders' do
            @sliders = Commander.new
            if params[:js]
              content_type "application/javascript"
              public_view(params[:js], 'js')
            elsif params[:css]
              content_type "text/css"
              public_view(params[:css], 'css')
            elsif params[:img]
              content_type "image/png"
              public_view(params[:img], 'images')
            else
              slider_view :index
            end
          end

          app.get '/sliders/:host' do
            @sliders = Commander.new
            slider_view :index
          end

          app.post '/sliders/:host' do
            if params[:quantity] && params[:queue]
              sliders = Commander.new
              queue = params[:queue].split.first
              quantity = params[:quantity].to_i
              if quantity.zero?
                sliders.delete(params[:host], queue)
              else
                sliders.change(params[:host], queue, quantity)
              end
            elsif params[:reload]
              sliders = Commander.new
              sliders.reload(params[:host])
            end
          end

          app.helpers do
            def slider_view(filename, options={}, locals={})
              erb(File.read(File.join(VIEW_PATH, "#{filename}.erb")), options, locals)
            end

            def public_view(filename, dir='')
              begin
                cache_control :public, :max_age => 1800
                file = File.join(PUBLIC_PATH, dir, filename)
                send_file file, :last_modified => File.mtime(file)
              rescue Errno::ENOENT
                404
              end
            end
          end

          app.tabs << "Sliders"

        end

      end
    end
  end
end

Resque::Server.register Resque::Plugins::ResqueSliders::Server
