module RSpec
  module Matchers
    module BuiltIn
      class BeWithin
        alias_method :orig_matches?, :matches?
        def matches? actual
          if Enumerable === actual && defined?(@expected)
            unless Enumerable === @expected
              raise ArgumentError.new("Expected value should be Enumerable, when actual is")
            end
            delta > super(actual).zip(@expected).map{|a,e| (a-e).abs}.max
          else
            orig_matches?(actual)
          end
        end
      end
    end
  end
end
