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
          attributes = tuple.header.each_with_object({}) do |attribute, document| 
            document[attribute.name] = tuple.call(attribute)
          end
          model.new(attributes)
        end
        memoize :object, :freezer => :noop

      end

      class Dumper
        include Adamantium::Flat, Concord.new(:model, :header, :object)

        def identity
          object.id
        end

        def tuple
          tuple = header.each_with_object([]) do |attribute, array| 
            array << object[attribute.name]
          end
          Axiom::Tuple.new(header, tuple)
        end
        memoize :tuple, :freezer => :noop
      end
    end
  end
end
