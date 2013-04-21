#encoding: utf-8
require 'spec_helper'
require 'pp'

describe DataMapper do

  specify 'spike' do

    class Person
      include Virtus::ValueObject

      attribute :id, Integer
      attribute :firstname, String
      attribute :lastname, String
    end

    header = Axiom::Relation::Header.coerce(
      [
        [:id,        Integer], 
        [:firstname, String], 
        [:lastname,  String]
      ]
    )

    # Basic 1:1 virtus transformer 
    transformer = DataMapper::Transformer::Virtus.new(Person, header)

    tuples = [
      [ 1, 'Markus', 'Schirp'    ], 
      [ 2, 'Dan',    'Kubb'      ], 
      [ 3, 'Piotr',  'Solnica'   ], 
      [ 4, 'Martin', 'Gamsjäger' ]
    ]

    relation = Axiom::Relation.new(header, tuples)

    mappers = {
      Person => DataMapper::Mapper.new(relation, transformer)
    }.freeze

    env = DataMapper::Environment.new(mappers)

    # Non tracked interactions
    markus = env.mapper(Person).one { |relation| relation.restrict(:firstname => 'Markus') }
    markus.should eql(Person.new(:id => 1, :firstname => 'Markus', :lastname => 'Schirp'))
    john = env.mapper(Person).one { |relation| relation.restrict(:firstname => 'John') }
    john.should be(nil)

    # Now lets add John
    # Does not deal with db side id generation, for now ;)
    env.mapper(Person).insert(Person.new(:id => 5, :firstname => 'John', :lastname => 'Doe'))
    john = env.mapper(Person).one { |relation| relation.restrict(:firstname => 'John') }
    john.should eql(Person.new(:id => 5, :firstname => 'John', :lastname => 'Doe'))

    # Remove John
    env.mapper(Person).delete(john)
    john = env.mapper(Person).one { |relation| relation.restrict(:firstname => 'John') }
    john.should be(nil)

    # Read all people
    # env.mapper(Person).all # => Enumerable<Person>
    # Pass an explicit restriction, might be from crazy joining some stuff....
    # env.mapper(Person).all(relation) # => Enumerable<Person>

    # Tracked interactions
    #
    # Exactly the same API as with the env object, just identity tracked and identity deduplicated.
    env.session do |session|
      first = session.mapper(Person).one do |relation|
        relation.restrict(:firstname => 'Markus')
      end
      
      second = session.mapper(Person).one do |relation|
        relation.restrict(:firstname => 'Markus')
      end

      # IM catches double load
      first.should be(second) 
    end
  end
end
