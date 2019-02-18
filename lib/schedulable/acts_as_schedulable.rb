module Schedulable
  
  module ActsAsSchedulable
    extend ActiveSupport::Concern
   
    included do
    end
   
    module ClassMethods
      
      def acts_as_schedulable(name, options = {})
        
        name ||= :schedules
        #attribute = :date
        
        has_many name, as: :schedulable, dependent: :destroy, class_name: 'Schedule' do
          # Schedules completely contained by a date range.
          def within(d1, d2)
            where("date >= ? AND until <= ?", d1, d2)
          end

          # Schedules partly contained by two dates.
          # Pass two dates or a Range object.
          def overlap(d1_or_range, d2=nil)
            dates = d1_or_range.is_a?(Range) ? d1_or_range : (d1_or_range..d2)
            where("until >= ? AND ? >= date", dates.first, dates.last)
          end
        end
        accepts_nested_attributes_for name, allow_destroy: true
        define_method "#{name}_attributes=" do |attribute_sets|
          super(
            attribute_sets.map do |i,attributes|
              attributes.merge(schedulable: self)
            end
          )
        end
        
        if options[:occurrences]
          
          # setup association
          if options[:occurrences].is_a?(String) || options[:occurrences].is_a?(Symbol)
            occurrences_association = options[:occurrences].to_sym
            options[:occurrences] = {}
          else
            occurrences_association = options[:occurrences][:name]
            options[:occurrences].delete(:name)
          end
          options[:occurrences][:class_name] = occurrences_association.to_s.classify
          options[:occurrences][:as]||= :schedulable
          options[:occurrences][:dependent]||:destroy
          options[:occurrences][:autosave]||= true
          
          has_many occurrences_association, options[:occurrences] do
#           def remaining
#             where("date >= ?", Time.current).order('date ASC')
#           end

#           def previous
#             where("date < ?", Time.current).order('date DESC')
#           end
          end
        end
      end
  
    end
    
  end
end  
