# test job class for resque

module Jobs
  class Stuff
    @queue = :stuff

    def self.perform(stuff)
      sleep(rand(30))
    end

  end

  class Things < Stuff
    @queue = :things
  end

  class Email < Stuff
    @queue = :email
  end

  class Support < Stuff
    @queue = :support
  end

  class Notification < Stuff
    @queue = :notification
  end
end
