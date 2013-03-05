module Mapper
  class Reader
    include Adamantium::Flat, Composition.new(:relation, :transformer)

    # Enumerate domain objects
    #
    # @return [self]
    #   if block given
    #
    # @return [Enumerable<Object>]
    #   otherwise
    # 
    def each(&block)
      return to_enum unless block_given?

      relation.each do |tuple|
        yield transformer.load(tuple)
      end
    end
  end
end
