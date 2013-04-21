module DataMapper

  class Session
    include Adamantium::Flat, Concord.new(:environment)

    def mapper(model)
      mapper = environment.mapper(model)
      Mapper.new(mapper.relation, Transformer.new(self, mapper.transformer))
    end

    def tracker
      {}
    end
    memoize :tracker, :freezer => :noop

    class Transformer
      include Concord.new(:session, :transformer)

      def load(tuple)
        loader = transformer.loader(tuple)
        tracker.fetch(loader.identity) do
          tracker[loader.identity] = loader.object
        end
      end

      def tracker
        session.tracker
      end
    end
  end

end
