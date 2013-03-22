#encoding: utf-8
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
          Veritas::Tuple.new(header, header.each_with_object([]) { |attribute, array| array << object[attribute.name] })
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
      other = Veritas::Relation.new(relation.header, [dump(object)])
      @relation = relation.insert(other)
      self
    end

    def delete(object)
      other = Veritas::Relation.new(relation.header, [dump(object)])
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
      if relation.kind_of?(Veritas::Relation::Operation::Order)
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

# Non tracked interactions
markus = env.mapper(Person).one { |relation| relation.restrict(:firstname => 'Markus') }
p markus # => Person instance
john = env.mapper(Person).one { |relation| relation.restrict(:firstname => 'John') }
p john # => nil
# Now lets add John
# Does not deal with db side id generation, for now ;)
env.mapper(Person).insert(Person.new(:id => 5, :firstname => 'John', :lastname => 'Doe'))
# Now we have John
john = env.mapper(Person).one { |relation| relation.restrict(:firstname => 'John') }
p john # => <Person firstname="John" ...>
# Remove John
env.mapper(Person).delete(john)
# Now he's gone
john = env.mapper(Person).one { |relation| relation.restrict(:firstname => 'John') }
p john # => nil
p env.mapper(Person).all # => Enumerable<Person>
# Pass an explicit restriction, might be from crazy joining some stuff....
p env.mapper(Person).all(relation) # => Enumerable<Person>

# Tracked interactions
env.session do |session|
  first = session.mapper(Person).one do |relation|
    relation.restrict(:firstname => 'Markus')
  end
  
  second = session.mapper(Person).one do |relation|
    relation.restrict(:firstname => 'Markus')
  end

  # IM catches double load
  p first.equal?(second) # => true
end
