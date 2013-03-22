#encoding: utf-8
$: << 'lib'
require 'dm-session'
require 'virtus'
require 'concord'
require 'veritas'
require 'veritas-sexp'
require 'pp'

class Person
  include Virtus::ValueObject

  attribute :id, Integer
  attribute :firstname, String
  attribute :lastname, String
end

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

        # Add itentity here for dm-session support

        def object
          model.new(tuple.header.each_with_object({}) { |attribute, document| document[attribute.name] = tuple.call(attribute) })
        end
        memoize :object, :freezer => :noop

      end

      class Dumper
        include Adamantium::Flat, Concord.new(:model, :header, :object)

        # Add itentity here for dm-session support

        def tuple
          object
        end
        memoize :tuple, :freezer => :noop
      end
    end
  end

  class Mapper
    include Concord.new(:relation, :transformer)

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
      if relation.kind_of?(Veritas::Relation::Operation::Order)
        return relation
      end
      # There must be a shortcut for this ;)
      relation.sort_by { relation.header.map(&:asc) }
    end

  end

  class Environment
    include Adamantium::Flat, Concord.new(:mappers)

    def mapper(model)
      mappers.fetch(model)
    end

  end
end

header = Veritas::Relation::Header.coerce([[:id, Integer], [:firstname, String], [:lastname, String]])

# Basic 1:1 virtus transformer 
transformer = DataMapper::Transformer::Virtus.new(Person, header)

tuples = [
  [ 1, 'Markus', 'Schirp'    ], 
  [ 2, 'Dan',    'Kubb'      ], 
  [ 3, 'Piotr',  'Solnica'   ], 
  [ 4, 'Martin', 'Gamsjäger' ]
]

relation = Veritas::Relation.new(header, tuples)

#pp Veritas::Sexp::Generator.visit(relation)

mappers = {
  Person => DataMapper::Mapper.new(relation, transformer)
}.freeze

env = DataMapper::Environment.new(mappers)

markus = env.mapper(Person).one { |relation| relation.restrict(:firstname => 'Markus') }
p markus # => Person instance

john = env.mapper(Person).one { |relation| relation.restrict(:firstname => 'John') }
p john # => nil

p env.mapper(Person).all # => Enumerable<Person>

# Pass an explicit restriction, might be from crazy joining some stuff....
p env.mapper(Person).all(relation) # => Enumerable<Person>

# More fun ahead with dm-session integration
