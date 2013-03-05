module Mapper
  module Virtus
    class Mapping
      include Composition.new(:model, :keys)
    end

    class Loader
      include Composition.new(:mapping, :tuple)

      # Return identity
      #
      # @return [Object]
      #
      # @api private
      #
      def identity
        mapping.keys.map { |key| tuple.call(key) }
      end
      memoize :identity

      # Return object
      #
      # @return [Object]
      #
      def object
        mapping.model.new(tuple)
      end
      memoize :object

    end

    class Dumper
      include Composition.new(:mapping, :object)

      # Return identity
      #
      # @return [Object]
      #
      # @api private
      #
      def identity
        mapping.keys.map { |key| object[key] }
      end
      memoize :identity

      # Return tuple
      #
      # @return [Tuple]
      #
      # @api private
      #
      def tuple
        object
      end
      memoize :tuple
    end
  end
end
