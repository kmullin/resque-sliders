module ResqueSliders
  module Server

    VIEW_PATH = File.join(File.dirname(__FILE__), 'server', 'views')
    PUBLIC_PATH = File.join(File.dirname(__FILE__), 'server', 'public')

    def self.registered(app)

      app.get '/sliders' do
        @sliders = Resque::Plugins::ResqueSliders.new
        slider_view :index
      end

      app.get '/sliders/:host' do
        @sliders = Resque::Plugins::ResqueSliders.new
        slider_view :index
      end

      app.post '/sliders/:host' do
        if params[:quantity] && params[:queue]
          sliders = Resque::Plugins::ResqueSliders.new
          queue = params[:queue].split.first
          quantity = params[:quantity].to_i
          if quantity.zero?
            sliders.delete(params[:host], queue)
          else
            sliders.change(params[:host], queue, quantity)
          end
        elsif params[:reload]
          sliders = Resque::Plugins::ResqueSliders.new
          sliders.reload(params[:host])
        end
      end

      app.helpers do
        def slider_view(filename, options={}, locals={})
          erb(File.read(File.join(VIEW_PATH, "#{filename}.erb")), options, locals)
        end
      end

      app.tabs << "Sliders"

    end

  end
end

Resque::Server.register ResqueSliders::Server
