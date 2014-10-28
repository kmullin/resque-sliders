module Resque
  module Plugins
    module ResqueSliders
      module Server

        VIEW_PATH = File.join(File.dirname(__FILE__), 'server', 'views')
        PUBLIC_PATH = File.join(File.dirname(__FILE__), 'server', 'public')

        def self.registered(app)
          require 'json'

          app.get '/sliders' do
            key = params.keys.first
            if %w(img css js).include? key
              public_view(params[key], key == 'img' ? 'images' : key)
            else
              @sliders = Commander.new
              redirect url_path("/sliders/#{@sliders.all_hosts.first}") if @sliders.all_hosts.length == 1
              slider_view :index
            end
          end

          app.get '/sliders/:host' do
            @sliders = Commander.new
            slider_view :index
          end

          app.post '/sliders/:host' do
            signals = params.reject { |x,y| x unless %w(pause stop play reload).include? x.to_s and y }
            sliders = Commander.new
            if params[:quantity] && params[:queue]
              queue = params[:queue].split.first
              quantity = params[:quantity].to_i
              sliders.change(params[:host], queue, quantity)
            elsif params[:queue] && params[:delete]
              queue = params[:queue].split.first
              sliders.delete(params[:host], queue)
            elsif signals.length == 1
              sig = signals.keys.first.to_s
              sliders.set_signal_flag(sig, params[:host])
              content_type :json
              {:signal => sig, :host => params[:host]}.to_json
            end
          end

          # we need the ability to remove old hosts
          app.delete '/sliders/:host' do
            Commander.new.remove_all_host_keys(params[:host])
          end

          app.helpers do
            def slider_view(filename, options={}, locals={})
              erb(File.read(File.join(VIEW_PATH, "#{filename}.erb")), options, locals)
            end

            def public_view(filename, dir='')
              file = File.join(PUBLIC_PATH, dir, filename)
              begin
                cache_control :public, :max_age => 1800
                send_file file
              rescue Errno::ENOENT
                404
              end
            end

            def daemon_buttons(host, list=true)
              html_out = []
              icon_base = 'ui-icon ui-corner-all ui-state-default'
              case
                when @sliders.reload?(host)
                  %w(pause stop alert)
                when (@sliders.pause?(host) or @sliders.stop?(host))
                  %w(play stop refresh)
                else
                  %w(pause stop refresh)
              end.each do |i|
                id = "#{host}:#{i.upcase}"
                klass = "#{icon_base} ui-icon-#{i}"
                klass += ' corner' unless list
                html_out << "<span id=\"#{id}\" class=\"#{klass}\"></span>"
              end
              if list
                '<li class="icons">' + html_out.join("</li><li class=\"icons\">") + '</li>'
              else
                html_out.reverse.join
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
