#encoding: utf-8
$: << 'lib'
require 'mapper'

class Person
  include Virtus

  attribute :id, Integer
  attribute :firstname, String
  attribute :lastname, String
end


header = Veritas::Relation::Header.coerce([[:id, Integer], [:firstname, String], [:lastname, String]], :keys => [:id])

transformer = Mapper::Transformer::Virtus.new(header, Person)

relation = Veritas::Relation.new(header, [[ 1, 'Markus', 'Schirp' ], [ 2, 'Dan', 'Kubb' ], [ 3, 'Piotr', 'Solnica' ], [ 4, 'Martin', 'Gamsjäger' ]])

Mapper::Reader.new(relation, transformer).each do |person|
  p person
end

