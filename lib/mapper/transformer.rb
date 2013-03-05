module Mapper
  class Transformer
    include AbstractType, Adamantium::Flat

    # Load tuple
    #
    # @param [Tuple] tuple
    #
    # @return [Object]
    #
    # @api private
    #
    def load(tuple)
      loader(tuple).object
    end

    # Dump object
    #
    # @param [Object] object
    #
    # @return [Tuple]
    #
    # @api private
    #
    def dump(object)
      dumper(object).tuple
    end

    # Return loader
    #
    # @param [Tuple] tuple
    #
    # @return [Loader]
    #
    abstract_method :loader

    # Return dumper
    #
    # @param [Object] 
    #
    # @return [Dumper]
    #
    # @api private
    #
    abstract_method :dumper

    class Virtus < self
      include Composition.new(:header, :model)

      # Return loader
      #
      # @param [Tuple] tuple
      #
      # @return [Virtus::Loader]
      #
      # @api private
      #
      def loader(tuple)
        Loader.new(self, tuple)
      end

      # Return dumper
      #
      # @param [Object] object
      #
      # @return [Virtus::Dumper]
      #
      # @api private
      #
      def dumper(object)
        Dumper.new(self, object)
      end

      class Loader
        include Adamantium::Flat, Composition.new(:transformer, :tuple)

        # Return identity
        #
        # @return [Object]
        #
        # @api private
        #
        def identity
          transformer.header.keys.map { |key| tuple.call(key) }
        end
        memoize :identity

        # Return object
        #
        # @return [Object]
        #
        def object
          attributes = transformer.header.each_with_object({}) do |attribute, hash|
            hash[attribute.name] = tuple.call(attribute.name)
          end
          transformer.model.new(attributes)
        end
        memoize :object

      end

      class Dumper
        include Adamantium::Flat, Composition.new(:transformer, :object)

        # Return identity
        #
        # @return [Object]
        #
        # @api private
        #
        def identity
          transformer.header.keys.map { |key| object[key] }
        end
        memoize :identity

        # Return tuple
        #
        # @return [Tuple]
        #
        # @api private
        #
        def tuple
          transformer.header.map do |attribute|
            object[attribute.name]
          end
        end
        memoize :tuple
      end

    end
  end
end
