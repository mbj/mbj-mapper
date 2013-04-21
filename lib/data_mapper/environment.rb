module DataMapper
  class Environment
    include Adamantium::Flat, Concord.new(:mappers)

    def session
      session = Session.new(self) 
      yield session if block_given?
      session
    end

    def mapper(model)
      mappers.fetch(model)
    end

  end
end
