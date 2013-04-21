require 'concord'
require 'virtus'
require 'axiom'
require 'axiom-sexp'

module DataMapper

  class Transformer
    # Minimal 1:1 virtus <=> tuple mapping
    class Virtus
      include Concord.new(:model, :header)

      def load(tuple)
        loader(tuple).object
      end

      def loader(tuple)
        Loader.new(model, header, tuple)
      end

      def dumper(object)
        Dumper.new(model, header, object)
      end

      def dump(object)
        dumper(object).tuple
      end

      class Loader
        include Adamantium::Flat, Concord.new(:model, :header, :tuple)

        def identity
          tuple.call(:id)
        end

        def object
          model.new(tuple.header.each_with_object({}) { |attribute, document| document[attribute.name] = tuple.call(attribute) })
        end
        memoize :object, :freezer => :noop

      end

      class Dumper
        include Adamantium::Flat, Concord.new(:model, :header, :object)

        def identity
          object.id
        end


        def tuple
          Axiom::Tuple.new(header, header.each_with_object([]) { |attribute, array| array << object[attribute.name] })
        end
        memoize :tuple, :freezer => :noop
      end
    end
  end

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

  class Mapper
    include Concord.new(:relation, :transformer)
    
    def insert(object)
      other = Axiom::Relation.new(relation.header, [dump(object)])
      @relation = relation.insert(other)
      self
    end

    def delete(object)
      other = Axiom::Relation.new(relation.header, [dump(object)])
      @relation = relation.delete(other)
    end

    def all(relation = self.relation)
      relation = yield relation if block_given?
      relation.map do |tuple|
        load(tuple)
      end
    end

    def one(relation = self.relation)
      relation = yield relation if block_given?
      tuples = sort(relation).take(2).to_a
      case tuples.length
      when 2
        raise "Read than one tuple"
      when 1
        load(tuples.first)
      else
        nil
      end
    end

  private

    def dump(object)
      transformer.dump(object)
    end

    def load(tuple)
      transformer.load(tuple)
    end

    # Sort relation if not sorted already ;)
    #
    # This is lame see my comment about Relation#sorted? predicate in dkubb/veritas.
    #
    # https://github.com/mbj/veritas/commit/ef70583330f4743d4a58374ef7d2077a7d996fc7#commitcomment-2863926
    #
    def sort(relation)
      if relation.kind_of?(Axiom::Relation::Operation::Order)
        return relation
      end
      # There must be a shortcut for this ;)
      relation.sort_by { relation.header.map(&:asc) }
    end

  end

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

