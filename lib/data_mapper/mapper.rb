module DataMapper

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

end
